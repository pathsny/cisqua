module Cisqua
  module Model
    module Saveable
      class DbProvider
        def initialize(redis)
          @redis = redis
          @cache = {}
          @incomplete_cache_writes = {}
          @counter = 0
        end

        def read(key)
          return @cache[key] if @cache.key?(key)

          yield(@redis).tap do |value|
            @cache[key] = value
          end
        end

        def bypass_cache
          yield(@redis)
        end

        def is_cached?(key)
          @cache.key?(key)
        end

        def update_cache(key, value)
          counter = start_update_cache(key, value)
          end_update_cache(key, counter)
        end

        def start_update_cache(key, value, new_value: false)
          unless new_value
            assert(
              @cache.key?(key),
              'trying to update cache with a key that is not in the cache',
            )
          end
          @counter += 1
          @incomplete_cache_writes[key] = @counter
          @cache[key] = value
          @counter
        end

        def end_update_cache(key, counter)
          assert(
            @incomplete_cache_writes[key] == counter,
            'end update cache without corresponding start',
          )
          @incomplete_cache_writes[key] = false
        end

        def write(transaction: nil, &block)
          if transaction.nil?
            transaction = Transaction.new(@redis)
            transaction.execute(&block)
          else
            # The transaction is already started and will be completed later.
            # So we only need to queue additional writes.
            transaction.queue_writes(&block)
          end
        end

        def clear_cache
          @cache.clear
        end
      end
    end
  end
end
