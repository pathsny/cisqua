require File.expand_path('libs', __dir__)

module Cisqua
  class PostProcessor
    include SemanticLogger::Loggable

    def initialize(options, scanner, file_processor)
      @options = options
      @file_process = file_processor
      @scanner = scanner
    end

    def start
      BatchProcessor.instance.start
    end

    def stop
      BatchProcessor.instance.stop
    end

    def make_on_process
      lambda do |state, batch_data|
        case state
        when :started, :process
          logger.info('progress', {
            count: batch_data.count,
            processed: batch_data.processed,
          })
        when :complete
          yield
        else
          raise "Unexpected state #{state} in script"
        end
      end
    end

    def run
      signal = Queue.new
      on_process = make_on_process { signal << true }
      result = BatchProcessor.instance.enqueue_request('Script', on_process)
      case result[:status]
      when :no_files
        log_no_files_banner
      when :started
        batch_data = result[:batch_data]
        log_start_banner(batch_data.count)
        signal.pop
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
