require 'faraday'

module Cisqua
  class BatchProcessor
    include Singleton
    include SemanticLogger::Loggable

    def initialize
      @input = Queue.new
      @signal = Queue.new
      @current = nil
      @on_update_callback = nil
    end

    # Since BatchProcessor is a singleton, the scanner has to be set rather than passed as an initializer.
    #   This allows BatchProcessor to know when there are files to process.
    # The metadatascraper needs a periodic check event. The start of a batch is convenient. So setting it
    #   allows the batch processor to take this action.
    attr_writer :scanner, :metadata_scraper
    attr_accessor :input, :signal, :options

    def on_update(&block)
      @on_update_callback = block
    end

    def start
      assert(@started.nil?, 'cannot start more than once')
      assert(!options.nil?, 'cannot start unless dependencies are set')

      fixup_batch_datas

      @started = true
      FileProcessor.instance.start
      @worker_thread = Thread.new do
        Thread.current.name = 'batch_worker'
        loop do
          assert(@current.nil?, 'This should never happen while processing a batch')
          item = input.pop
          break if item == :end # Trying to quit

          process(**item)
        end
      end
      @worker_thread.abort_on_exception = true
    end

    def fixup_batch_datas
      previous_batch_datas = BatchCheck.instance.latest(10)
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

    # Runs on the thread of the caller
    def enqueue_request(request_source)
      return { status: :rejected } if input.size == 1 # There is already a queued up job waiting.

      if @current.nil?
        check_and_create_batch(request_source:).tap do |result|
          input << result
        end
      else
        # A job is running. So we just queue up a job to wait
        { status: :waiting, request_source: }.tap { |d| input << d }
      end
    end

    def record_anime_name_change(aid, old_name, new_name, transaction:)
      return unless @started && !@current.nil?

      AnimeNameChange.new.update(
        transaction:,
        batch_data_id: @current.id,
        aid:,
        old_name:,
        new_name:,
      )
    end

    private

    # Triggers a check from the request_source
    # Creates a new batch to process if appropriate.
    def check_and_create_batch(request_source:)
      assert(@current.nil?, 'cannot create a new batch when a process is running')

      sources = @scanner.work_item_sources
      logger.debug('got a request', { count: sources.count })
      if sources.empty?
        BatchCheck.update_no_files(request_source:)
        return { status: :no_files, request_source: }
      end

      work_items = []
      batch_data = BatchCheck.update_new_files(request_source:, source_count: sources.count) do |index|
        source = sources[index]
        work_items << WorkItem.new(source:, request_type: :standard, index:)
        source.name
      end
      { status: :started, request_source:, work_items:, batch_data: }
    end

    def process(result)
      if result[:status] == :waiting
        result = check_and_create_batch(request_source:)
      end

      if result[:status] == :no_files
        @on_update_callback.call(event: :check, result:)
        return
      end

      assert(result[:status] == :started, 'only valid status')
      @current = result[:batch_data]
      @on_update_callback.call(
        event: :check,
        result: result.slice(:status, :request_source),
        batch_data: result[:batch_data],
      )
      process_batch(**result)
    end

    def process_batch(work_items:, batch_data:, **)
      @metadata_scraper.ensure_mapping
      logger.info('Processing batch', id: batch_data.id, count: work_items.count)

      FileProcessor.instance.record_file_identity_callback = batch_data.method(:record_file_identity)

      atleast_one_success_phase_1, dups = process_items(
        :standard,
        batch_data,
        work_items,
      )
      atleast_one_success ||= atleast_one_success_phase_1
      dest_root = File.absolute_path(options.renamer[:output_location], ROOT_FOLDER)

      dup_work_items = dups.map.with_index do |(destination, duplicates), index|
        name = Pathname.new(destination).relative_path_from(Pathname.new(dest_root)).to_s
        WorkItem.new(
          source: WorkItemSource.new(path: destination, name:),
          request_type: :duplicate_set,
          duplicate_work_items: duplicates,
          index: "dup_set_#{index}",
        )
      end

      unless dup_work_items.empty?
        logger.info('Processing duplicate set', count: dup_work_items.count)
        atleast_one_success_phase_2, dup_dups = process_items(
          :duplicate_set,
          batch_data,
          dup_work_items,
        )
        atleast_one_success ||= atleast_one_success_phase_2
        assert(dup_dups.empty?, 'cannot get dups of dups')
      end

      FileProcessor.instance.record_file_identity_callback = nil

      post_batch_actions(atleast_one_success)

      complete_batch(batch_data)
    end

    def complete_batch(batch_data)
      batch_data.update(is_complete: true)
      @current = nil
      @on_update_callback.call(event: :complete, batch_data:)
    end

    def on_process(batch_data, work_item, result, batch_progress)
      if result.type == :unknown
        batch_data.record_file_result(work_item.index, result: result.type)
        logger.warn(
          'UNKNOWN file',
          source: work_item.source.path,
          dest: result.destination,
          batch_progress:,
          processed: "#{batch_data.processed}/#{batch_data.count}",
        )
      else
        case result.type
        when :success
          batch_data.record_file_result(work_item.index, result: result.type, fid: work_item.file.id)
          logger.info(
            'MOVING File',
            source: work_item.source.path,
            dest: result.destination,
            batch_progress:,
            processed: "#{batch_data.processed}/#{batch_data.count}",
          )
        when :duplicate
          logger.warn(
            'DUPLICATE file',
            source: work_item.source.path,
            dest: result.destination,
            batch_progress:,
            processed: "#{batch_data.processed}/#{batch_data.count}",
          )
        when :resolved_duplicates_unchanged, :resolved_duplicates_replaced
          { junk: result.junk, dup: result.dups }.each do |type, items|
            items.each do |w|
              # The standard requests are for newly scanned files. Thats why
              # we only record it's progress
              next if w.request_type != :standard

              batch_data.record_file_result(w.index, result: type, fid: w.file.id)
            end
          end

          if result.type == :resolved_duplicates_replaced
            new_item = result.replacement[:new_item]
            batch_data.record_file_result(new_item.index,
              result: :replacement,
              fid: new_item.file.id.to_s,
              replaced_fid: result.replacement[:old_item].file.id.to_s,
              reason: result.replacement[:reason])
          end
          if result.type == :resolved_duplicates_unchanged
            logger.info(
              'RETAINING file',
              source: result.destination,
              batch_progress:,
              processed: "#{batch_data.processed}/#{batch_data.count}",
            )
          else
            logger.info(
              'REPLACING file',
              source: result.replacement[:new_item].source.path,
              dest: work_item.source.path,
              reason: result.replacement[:reason],
              batch_progress:,
              processed: "#{batch_data.processed}/#{batch_data.count}",
            )
          end
        else
          raise "Unknown response type #{result.type}"
        end
      end
      @on_update_callback.call(event: :process, batch_data:)
    end

    # runs on processor thread
    def process_items(type, batch_data, work_items)
      logger.debug("Processing #{work_items.count} #{type} items")
      results = {}
      results.compare_by_identity
      work_items.each do |work_item|
        FileProcessor.instance.process(work_item) do |result|
          results[work_item] = result
          on_process(batch_data, work_item, result, "#{results.count}/#{work_items.count}")
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
            status: resp.status,
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
