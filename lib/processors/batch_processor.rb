require 'faraday'

module Cisqua
  class BatchProcessor
    include Singleton
    include SemanticLogger::Loggable

    def initialize
      @input = Queue.new
      @signal = Queue.new
      @current = nil
    end

    attr_writer :scanner
    attr_accessor :input, :signal, :options

    def start
      raise 'cannot start more than once' if @started
      raise 'cannot start unless dependencies are set' if options.nil?

      fixup_batch_datas

      @started = true
      FileProcessor.instance.start
      @worker_thread = Thread.new do
        Thread.current.name = 'batch_worker'
        loop do
          item = input.pop
          break if item == :end

          assert(item[:status] == :started, 'at this point the batch should have started')

          process(**item)
        end
      end
      @worker_thread.abort_on_exception = true
    end

    def fixup_batch_datas
      previous_batch_datas = BatchData.latest(10)
      previous_batch_datas.each do |bd|
        unless bd.complete?
          logger.warn('batch_data incomplete on startup. Probably aborted', batch_data: bd.id)
          bd.update(is_complete: true)
        end
      end
    end

    def stop
      FileProcessor.instance.stop
      input << :end
      @worker_thread.join
    end

    def enqueue_request(request_source, on_update)
      return { status: :rejected } if input.size == 1 # There is already a queued up job waiting.

      if @current.nil?
        check_and_process(request_source:, on_update:)
      else
        # A job is running. So we just queue up a job to wait
        { status: :waiting, on_update:, request_source: }.tap { |d| input << d }
      end
    end

    private

    def check_and_process(request_source:, on_update:, **)
      assert(@current.nil?, 'cannot start a new batch while one is in progress')

      work_items = @scanner.work_item_files.map do |file|
        WorkItem.new(file:, request_type: :standard)
      end

      logger.debug('got a request', { count: work_items.count })

      if work_items.empty?
        BatchCheck.update(request_source:, batch_data_id: '')
        return { status: :no_files }
      end

      batch_data = BatchData.create(
        request_source,
        work_items.count,
      )
      BatchCheck.update(request_source:, batch_data_id: batch_data.id)
      @current = batch_data
      { status: :started, work_items:, batch_data:, on_update: }.tap { |d| input << d }
    end

    def complete_batch(batch_data, on_update)
      batch_data.update(is_complete: true)
      @current = nil
      # We want to complete the batch, and it could be as simple as marking it complete
      # and triggering the callback. But there is a chance that there is a job waiting.
      # so lets make sure we allow the next job to start before we call the callback
      unless input.empty?
        data = input.pop
        if data == :end
          # it was trying to end, lets allow it continue doing so
          input << data
        else
          assert(data[:status] == :waiting, 'The only possibility is that there was a waiting job')
          check_and_process(**data)
        end
      end
      on_update.call(:complete, batch_data)
    end

    def process(work_items:, batch_data:, on_update:, **)
      on_update.call(:started, batch_data)
      atleast_one_success_phase_1, dups = process_items(
        :standard,
        batch_data,
        on_update,
        work_items,
      )
      atleast_one_success ||= atleast_one_success_phase_1
      dest_root = File.absolute_path(options.renamer[:output_location], ROOT_FOLDER)
      dup_work_items = dups.map do |destination, duplicates|
        name = Pathname.new(destination).relative_path_from(Pathname.new(dest_root)).to_s
        WorkItem.new(
          file: WorkItemFile.new(path: destination, name:),
          request_type: :duplicate_set,
          duplicate_work_items: duplicates,
        )
      end

      unless dup_work_items.empty?
        atleast_one_success_phase_2, dup_dups = process_items(
          :duplicate_set,
          batch_data,
          on_update,
          dup_work_items,
        )
        atleast_one_success ||= atleast_one_success_phase_2
        assert(dup_dups.empty?, 'cannot get dups of dups')
      end

      post_batch_actions(atleast_one_success)

      complete_batch(batch_data, on_update)
    end

    def on_process(batch_data, on_update, work_item, result)
      case result.type
      when :success
        logger.info(
          'MOVING File',
          source: work_item.file.path,
          dest: result.destination,
        )
        batch_data.add_success_fid(work_item.info[:fid])
      when :unknown
        logger.warn(
          'UNKNOWN file',
          source: work_item.file.path,
          dest: result.destination,
        )
        batch_data.add_unknown(work_item.file.name)
      when :resolved_duplicates_unchanged
        logger.info(
          'RETAINING file',
          source: result.destination,
        )
        batch_data.add_duplicate_fids(
          work_item.duplicate_work_items.map { |w| w.info[:fid] },
        )
      when :resolved_duplicates_replaced
        logger.info(
          'REPLACING file',
          source: result.work_item.file.path,
          dest: work_item.file.path,
        )
        dup_work_items = work_item.duplicate_work_items.select { |w| w != result.work_item }
        unless dup_work_items.empty?
          batch_data.add_duplicate_fids(
            dup_work_items.map { |w| w.info[:fid] },
          )
        end
        batch_data.add_replacement_fid(result.work_item.info[:fid])
      when :duplicate
        logger.warn(
          'DUPLICATE file',
          source: work_item.file.path,
          dest: result.destination,
        )
      end
      on_update.call(:process, batch_data)
    end

    # runs on processor thread
    def process_items(type, batch_data, on_update, work_items)
      logger.debug("Processing #{work_items.count} #{type} items")
      results = {}
      results.compare_by_identity
      work_items.each do |work_item|
        FileProcessor.instance.process(work_item) do |result|
          results[work_item] = result
          on_process(batch_data, on_update, work_item, result)
          signal << true if results.count == work_items.count
        end
      end
      signal.pop

      assert('when processing duplicates, all must succeed') do
        results.all? { |w, res| w.request_type == :standard || res.type != :duplicate }
      end

      atleast_one_success = results.any? { |_, r| r.type == :success }
      duplicates = work_items.filter { |w| results[w].type == :duplicate }
      duplicate_groups = duplicates.group_by { |w| results[w].destination }

      FileProcessor.instance.assert_no_pending_work

      [atleast_one_success, duplicate_groups]
    end

    def post_batch_actions(atleast_one_success)
      post_batch_actions = options[:post_batch_actions]
      plex_scan_library_files(post_batch_actions[:plex_scan_library_files]) if atleast_one_success
      return unless post_batch_actions[:clean_up_empty_dirs]

      basedir = File.absolute_path(options[:scanner][:basedir], ROOT_FOLDER)
      raise 'empty basedir' unless basedir

      Dir["#{basedir}/**/*"]
        .select { |d| File.directory?(d) }
        .sort { |a, b| b <=> a }
        .each { |d| Dir.rmdir(d) if Dir.empty?(d) }
    end

    def plex_scan_library_files(plex_opt)
      return unless plex_opt

      uri = URI::HTTP.build(
        host: plex_opt[:host],
        port: plex_opt[:port],
        path: "/library/sections/#{plex_opt[:section]}/refresh",
      ).to_s
      logger.debug(
        'updating plex',
        plex_server: uri,
      )
      begin
        resp = Faraday.get(uri, { 'X-Plex-Token': plex_opt[:token] })
        if resp.status == 200
          logger.info(
            'Requested plex server to scan library files',
            plex_server: uri,
          )
        else
          logger.error(
            'could not update plex',
            plex_server: uri,
            code: resp.code,
            body: resp.body,
          )
        end
      rescue StandardError => e
        logger.error(
          'could not update plex',
          plex_server: uri,
          exception: e,
          log_exception: :full,
        )
      end
    end
  end
end
