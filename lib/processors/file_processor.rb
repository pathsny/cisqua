module Cisqua
  # This is a singleton. Files to process are read from a queue
  # and responses are returned on a different queue.

  # Possible Responses
  # :success: The file has been processed, nothing further to be done. This could
  #   be because this file was recognized and there were no issues processing it or
  #   because this file is an already processed file being compared against one or more
  #   files that will replace it. In either case, a well understood action has been taken
  #   and there is no further action required.
  # :unknown: The file is not recognized, it too has been processed.
  # :duplicate: The file will overwrite an existing file
  class FileProcessor
    include Singleton
    include SemanticLogger::Loggable

    def initialize
      @scan_queue = Queue.new
      @info_queue = Queue.new
      @renamer_queue = Queue.new
      @workers = []
      @on_done_map = {}
      @on_done_map.compare_by_identity
    end

    attr_reader :on_done_map

    def set_dependencies(scanner, api_client, renamer)
      @scanner = scanner
      @api_client = api_client
      @renamer = renamer
    end

    def assert_no_pending_work
      assert(
        @scan_queue.empty? && @renamer_queue.empty? && @info_queue.empty? && @on_done_map.empty?,
        'all queues and maps must be empty',
      )
    end

    def start
      raise 'cannot start more than once' if @started
      raise 'cannot start unless dependencies are set' if [@scanner, @api_client, @renamer].any?(&:nil?)

      @started = true
      make_worker('scanner') do
        pipe_work_items(@scan_queue, @info_queue) { |w| scan(w) }
      end
      make_worker('info_getter') do
        pipe_work_items(@info_queue, @renamer_queue) { |w| fetch_info(w) }
        @api_client.disconnect
      end
      make_worker('renamer') do
        while_queue_has_items(@renamer_queue) do |w|
          result = rename(w)
          on_done = on_done_map.delete(w)
          on_done.call(result)
        end
      end
    end

    def stop
      @scan_queue << :end
      @workers.each(&:join)
    end

    def process(work_item, &on_done)
      @scan_queue << work_item
      on_done_map[work_item] = on_done
    end

    def make_worker(name)
      worker = Thread.new do
        Thread.current.name = name
        yield
      end
      @workers << worker
      worker.abort_on_exception = true
    end

    def rename(work_item)
      @renamer.process(work_item)
    end

    def fetch_info(work_item)
      file = work_item.file
      work_item.info = @api_client.process(file.path, file.ed2k, file.size_bytes)
    end

    def scan(work_item)
      file = work_item.file
      size, ed2k = @scanner.ed2k_file_hash(file.path)
      file.size_bytes = size
      file.ed2k = ed2k
      logger.debug(
        'file scanned',
        ed2k:,
        size:,
      )
    end

    def while_queue_has_items(queue)
      until (work_item = queue.pop) == :end
        SemanticLogger.tagged(file: work_item.file.path) do
          yield work_item
        end
      end
    end

    def pipe_work_items(source_queue, destination_queue)
      while_queue_has_items(source_queue) do |w|
        destination_queue << w.tap { yield(w) }
      end
      destination_queue << :end
    end
  end
end
