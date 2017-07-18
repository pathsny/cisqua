require 'concurrent-edge'
require_relative '../../lib/loggers'
require_relative '../../lib/post_processor'
# require_relative '../../model/scheduled_task'

class Tasks
  @pp_executor = Concurrent::SingleThreadExecutor.new
  @scheduled_task_executor = Concurrent::SingleThreadExecutor.new

  Kernel.at_exit {
    Loggers::Tasks.info { "shutting down thread pool" }
    @pp_executor.shutdown
    @pp_executor.wait_for_termination
  }

  class << self
    def post_process
      Loggers::Tasks.info { "post process triggered, current queue length is #{@pp_executor.queue_length} " }
      return if @pp_executor.queue_length > 0
      Concurrent.future(@pp_executor) {
        begin
        PostProcessor.run(false)
      rescue Exception => e
        Loggers::Tasks.warn { "could not post process : because #{e}" }
      end 
      }.then(:io) {
        Loggers::Tasks.info { "post process ended" }
      }.rescue(:io) { |reason|
        Loggers::Tasks.warn { "could not post process : because #{reason}" }
      }
    end   
  end  
end