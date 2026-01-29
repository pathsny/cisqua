module Cisqua
  module Model
    module Saveable
      module Associations
        # Proxy for a redis set of ids

        class AssociatedIdsSetProxy
          include Enumerable
          include SemanticLogger::Loggable

          attr_reader :redis_key

          def initialize(db_provider, redis_key, debug_info)
            @db_provider = db_provider
            @redis_key = redis_key
            @debug_info = debug_info
          end

          def include?(id)
            if @db_provider.is_cached?(redis_key)
              return @db_provider.read(redis_key).include?(id)
            end

            @db_provider.read(member_cache_key(id)) do |redis|
              redis.sismember(@redis_key, id)
            end
          end

          def to_set
            @db_provider.read(redis_key) do |redis|
              Set.new(redis.smembers(@redis_key))
            end
          end

          def to_a
            to_set.to_a
          end

          def length
            if @db_provider.is_cached?(redis_key)
              return @db_provider.read(redis_key).count
            end

            @db_provider.read(count_cache_key) do |redis|
              redis.scard(@redis_key)
            end
          end

          def each(&)
            return to_enum(:each) unless block_given?

            to_a.each(&)
          end

          def empty?
            length.zero?
          end

          alias member? include?
          alias size length

          def last
            to_a.last
          end

          def add_many(ids:, transaction: nil)
            return if ids.empty?

            normalized_ids = ids.map(&:to_s)
            add_result = nil
            @db_provider.write(transaction:) do |t|
              t.add_operation do |pipeline|
                add_result = pipeline.sadd(@redis_key, *normalized_ids)
              end
              t.on_complete do
                _after_add(add_result.value, *normalized_ids)
              end
            end
          end

          def _after_add(num_added, *ids)
            return if num_added.zero?

            ids.each do |id|
              next unless @db_provider.is_cached?(member_cache_key(id))

              @db_provider.update_cache(member_cache_key(id), true)
            end

            if @db_provider.is_cached?(count_cache_key)
              count = @db_provider.read(count_cache_key)
              @db_provider.update_cache(count_cache_key, count + num_added)
            end

            if @db_provider.is_cached?(redis_key)
              cached_ids = @db_provider.read(redis_key)
              @db_provider.update_cache(redis_key, cached_ids.merge(ids))
            end
          end

          def remove_many(ids:, transaction: nil)
            return if ids.empty?

            normalized_ids = ids.map(&:to_s)
            remove_result = nil
            @db_provider.write(transaction:) do |t|
              t.add_operation do |pipeline|
                remove_result = pipeline.srem(@redis_key, *normalized_ids)
              end
              t.on_complete do
                _after_remove(remove_result.value, *normalized_ids)
              end
            end
          end

          def _after_remove(num_removed, *ids)
            return if num_removed.zero?

            ids.each do |id|
              next unless @db_provider.is_cached?(member_cache_key(id))

              @db_provider.update_cache(member_cache_key(id), false)
            end

            if @db_provider.is_cached?(count_cache_key)
              count = @db_provider.read(count_cache_key)
              @db_provider.update_cache(count_cache_key, count - num_removed)
            end

            if @db_provider.is_cached?(redis_key)
              cached_ids = @db_provider.read(redis_key)
              @db_provider.update_cache(redis_key, cached_ids.subtract(ids))
            end
          end

          def count_cache_key
            "#{redis_key}_count"
          end

          def member_cache_key(id)
            "#{redis_key}_member_#{id}"
          end

          def pretty_print_instance_variables
            (instance_variables - %i[@db_provider @cache]).sort
          end
        end
      end
    end
  end
end
