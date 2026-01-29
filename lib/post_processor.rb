require File.expand_path('libs', __dir__)

module Cisqua
  class PostProcessor
    include SemanticLogger::Loggable

    def initialize(options, scanner, file_processor)
      @options = options
      @file_process = file_processor
      @scanner = scanner
      @signal = Queue.new
    end

    def start
      LifeCycle.instance.start_processors
      BatchProcessor.instance.on_update(&method(:on_batch_update))
    end

    def stop
      LifeCycle.instance.stop_processors
    end

    def on_batch_update(event:, result: nil, batch_data: nil)
      logger.info('Batch Process Event', event:)

      case event
      when :check
        logger.info('Check Result', result:)
      when :process
        logger.info('progress', {
          count: batch_data.count,
          processed: batch_data.processed,
        })
      when :complete
        @signal << true
      else
        raise "invalid event type #{event}"
      end
    end

    def run
      result = BatchProcessor.instance.enqueue_request('Script')
      case result[:status]
      when :no_files
        log_no_files_banner
      when :started
        batch_data = result[:batch_data]
        log_start_banner(batch_data.count)
        @signal.pop
        log_end_banner(batch_data.count)
      else
        "invalid result #{result} from batch processor for script"
      end
    end

    def log_no_files_banner
      logger.info('=========================================')
      logger.info("Starting Fresh Run at #{Time.now}, no eligible files")
      logger.info('=========================================')
    end

    def log_start_banner(num_files)
      logger.info('=========================================')
      logger.info("Starting Fresh Run at #{Time.now} for #{num_files} files")
      logger.info('=========================================')
    end

    def log_end_banner(num_files)
      logger.info('=========================================')
      logger.info("Completed Job and processed #{num_files} files")
      logger.info('=========================================')
    end
  end
end
