module Cisqua
  module Model
    module Saveable
      attr_reader :old_cache_values

      class Transaction
        def initialize(redis)
          @redis = redis
          @operations = []
          @on_completes = []
          @on_rollbacks = []
          @state = :pending
        end

        def execute(&block)
          raise 'cannot rerun a transaction' if @state == :done

          @state = :executing

          queue_writes(&block).tap do |_result|
            begin
              @redis.multi do |pipeline|
                @operations.each { |op| op.call(pipeline) }
              end
              @state = :done
            rescue StandardError
              @on_rollbacks.each(&:call)
              raise
            end
            @on_completes.each(&:call)
          end
        end

        def queue_writes(&block)
          block.call(self)
        end

        def add_operation(&block)
          @operations << block
        end

        def on_complete(&block)
          @on_completes << block
        end

        def on_rollback(&block)
          @on_rollbacks << block
        end
      end
    end
  end
end
