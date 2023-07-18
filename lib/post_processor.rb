require File.expand_path('libs', __dir__)
require 'resolv-replace'

class PostProcessor
  class << self
    def run(options, test_mode)
      files = FileScanner.file_list(options[:scanner])
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

      scanner = Thread.new do
        pipe_while_queue_has_items(scan_queue, info_queue) do |w|
          w.tap do |work_item|
            file = work_item.file
            size, ed2k = FileScanner.ed2k_file_hash(file.name)
            Loggers::PostProcessor.debug "file #{file.name} has ed2k hash #{ed2k}"
            file.size_bytes = size
            file.ed2k = ed2k
          end
        end
      end

      info_getter = Thread.new do
        Thread.current.name = 'info_getter'
        anidb_api = APIClient.new(options[:api_client], test_mode)
        pipe_while_queue_has_items(info_queue, rename_queue) do |w|
          w.tap do |work_item|
            file = work_item.file
            work_item.info = anidb_api.process(file.name, file.ed2k, file.size_bytes)
          end
        end
        anidb_api.disconnect
      end

      rename_worker = Thread.new do
        renamer = Renamer::Renamer.new(options[:renamer])
        dups = {}
        success = {}
        files.each do
          work_item = rename_queue.pop
          res = renamer.try_process(work_item)
          case res.type
          when :success
            Loggers::PostProcessor.info(
              "MOVING \n\t#{work_item.file.name} ===>\n\t#{res.destination}",
            )
            success[res.destination] = work_item
          when :unknown
            dest_string = res.destination ? "  ===>\n\t#{res.destination}" : ''
            Loggers::PostProcessor.warn(
              "UNKNOWN file\n\t#{work_item.file.name}#{dest_string}",
            )
          when :duplicate
            Loggers::PostProcessor.warn(
              "DUPLICATE file \n\t#{work_item.file.name} <=>\n\t#{res.destination}",
            )
            dups[res.destination] = dups[res.destination] || []
            dups[res.destination].push(work_item)
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

          renamer.process_duplicate_set(
            WorkItem.new(
              file: WorkItemFile.new(name: k),
              info: success[k].info,
            ),
            items,
          )
        end

        # resolve duplicates as we get legacy info
        while_queue_has_items(rename_queue) do |work_item|
          renamer.process_duplicate_set(work_item, dups[work_item.file.name])
        end

        renamer.post_rename_actions
      end

      scanner.abort_on_exception = true
      info_getter.abort_on_exception = true
      rename_worker.abort_on_exception = true

      files.each do |f|
        work_item = WorkItem.new(file: WorkItemFile.new(name: f))
        scan_queue << work_item
      end

      [scanner, info_getter, rename_worker].each(&:join)
      return unless options[:clean_up_empty_dirs]

      basedir = File.absolute_path(options[:scanner][:basedir], ROOT_FOLDER)
      raise 'empty basedir' unless basedir

      system "find /#{basedir} -type f -name \"tvshow.nfo\" -delete"

      Dir["#{basedir}/**/*"]
        .select { |d| File.directory?(d) }
        .sort { |a, b| b <=> a }
        .each { |d| Dir.rmdir(d) if Dir.empty?(d) }

      log_end_banner
    end

    def log_start_banner
      Loggers::PostProcessor.info('=========================================')
      Loggers::PostProcessor.info("Starting Fresh Run at #{Time.now}")
      Loggers::PostProcessor.info('=========================================')
    end

    def log_end_banner
      Loggers::PostProcessor.info('=========================================')
      Loggers::PostProcessor.info('Completed Job')
      Loggers::PostProcessor.info('=========================================')
    end
  end
end
