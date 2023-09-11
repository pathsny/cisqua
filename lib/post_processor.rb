require File.expand_path('libs', __dir__)
require 'resolv-replace'
require File.join(Cisqua::ROOT_FOLDER, 'integration_spec', 'test_util')

module Cisqua
  class PostProcessor
    include SemanticLogger::Loggable
    class << self
      def run(options, scanner, api_client, renamer)
        files = scanner.file_list
        Thread.current.name = 'main'

        log_start_banner
        scan_queue = Queue.new
        info_queue = Queue.new
        rename_queue = Queue.new

        def while_queue_has_items(queue)
          until (item = queue.pop) == :end
            yield item
          end
        end

        def pipe_while_queue_has_items(source_queue, destination_queue)
          while_queue_has_items(source_queue) do |source_item|
            destination_queue << yield(source_item)
          end
          destination_queue << :end
        end

        scanner_worker = Thread.new do
          Thread.current.name = 'scanner'

          pipe_while_queue_has_items(scan_queue, info_queue) do |w|
            SemanticLogger.tagged(file: w.file.name) do
              w.tap do |work_item|
                file = work_item.file
                size, ed2k = scanner.ed2k_file_hash(file.name)
                file.size_bytes = size
                file.ed2k = ed2k
                logger.debug(
                  'file scanned',
                  ed2k:,
                  size:,
                )
              end
            end
          end
        end

        info_getter = Thread.new do
          Thread.current.name = 'info_getter'

          pipe_while_queue_has_items(info_queue, rename_queue) do |w|
            SemanticLogger.tagged(file: w.file.name) do
              w.tap do |work_item|
                file = work_item.file
                work_item.info = api_client.process(file.name, file.ed2k, file.size_bytes)
              end
            end
          end
          api_client.disconnect
        end

        rename_worker = Thread.new do
          Thread.current.name = 'renamer'
          dups = {}
          success = {}
          files.each do
            work_item = rename_queue.pop
            SemanticLogger.tagged(file: work_item.file.name) do
              res = renamer.try_process(work_item)
              case res.type
              when :success
                logger.info(
                  'MOVING File',
                  source: work_item.file.name,
                  dest: res.destination,
                )
                success[res.destination] = work_item
              when :unknown
                dest_string = res.destination ? "  ===>\n\t#{res.destination}" : ''
                logger.warn(
                  'UNKNOWN file',
                  source: work_item.file.name,
                  dest: dest_string,
                )
              when :duplicate
                logger.warn(
                  'DUPLICATE file',
                  source: work_item.file.name,
                  dest: res.destination,
                )
                dups[res.destination] = dups[res.destination] || []
                dups[res.destination].push(work_item)
              end
            end
          end
          dups.each do |k, _|
            work_item = WorkItem.new(file: WorkItemFile.new(name: k))
            # rescan the duplicates unless we have it in the success map
            scan_queue << work_item unless success.key?(k)
          end
          scan_queue << :end

          # resolve duplicates immideately for when we have all the info
          dups.each do |k, items|
            next unless success.key?(k)

            SemanticLogger.tagged(file: k) do
              renamer.process_duplicate_set(
                WorkItem.new(
                  file: WorkItemFile.new(name: k),
                  info: success[k].info,
                ),
                items,
              )
            end
          end

          # resolve duplicates as we get legacy info
          while_queue_has_items(rename_queue) do |work_item|
            SemanticLogger.tagged(file: work_item.file.name) do
              renamer.process_duplicate_set(work_item, dups[work_item.file.name])
            end
          end

          renamer.post_rename_actions
        end

        scanner_worker.abort_on_exception = true
        info_getter.abort_on_exception = true
        rename_worker.abort_on_exception = true

        files.each do |f|
          work_item = WorkItem.new(file: WorkItemFile.new(name: f))
          scan_queue << work_item
        end

        [scanner_worker, info_getter, rename_worker].each(&:join)
        return unless options[:clean_up_empty_dirs]

        basedir = File.absolute_path(options[:scanner][:basedir], ROOT_FOLDER)
        raise 'empty basedir' unless basedir

        system "find /#{basedir} -type f -name \"tvshow.nfo\" -delete"

        Dir["#{basedir}/**/*"]
          .select { |d| File.directory?(d) }
          .sort { |a, b| b <=> a }
          .each { |d| Dir.rmdir(d) if Dir.empty?(d) }

        log_end_banner(files.count)
      end

      def log_start_banner
        logger.info('=========================================')
        logger.info("Starting Fresh Run at #{Time.now}")
        logger.info('=========================================')
      end

      def log_end_banner(num_files)
        logger.info('=========================================')
        logger.info("Completed Job and processed #{num_files} files")
        logger.info('=========================================')
      end

      def make_client(api_options)
        params = %i[host port localport user pass nat].map { |k| api_options[k] }
        logger = SemanticLogger[Net::AniDBUDP]
        logger.instance_eval("def proto(v = '') ; self.debug v ; end", __FILE__, __LINE__)
        Net::AniDBUDP.new(*params, logger)
      end
    end
  end
end
