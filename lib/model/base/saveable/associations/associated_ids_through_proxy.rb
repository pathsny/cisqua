module Cisqua
  module Model
    module Saveable
      module Associations
        # Proxy for a redis set of ids

        class AssociatedIdsThroughProxy
          include Enumerable
          include SemanticLogger::Loggable

          def initialize(redis_key, proxy_assoc, get_intermediate_proxy, debug_info)
            @redis_key = redis_key
            @debug_info = debug_info
            @get_intermediate_proxy = get_intermediate_proxy
            @proxy_assoc = proxy_assoc
          end

          def include?(id)
            _intermediate_proxy.any? do |intermediate_instance|
              ids = @proxy_assoc.target_ids_from_instance(intermediate_instance)
              ids.include?(id)
            end
          end

          def _intermediate_proxy
            @get_intermediate_proxy.call
          end

          def to_set
            _intermediate_proxy.each_with_object(Set.new) do |intermediate_instance, set|
              set.merge(@proxy_assoc.target_ids_from_instance(intermediate_instance))
            end
          end

          def to_a
            to_set.to_a
          end

          def length
            to_set.length
          end

          def each(&block)
            return to_enum(:each) unless block_given?

            to_a.each do |id|
              block.call(id)
            end
          end

          alias member? include?
          alias size length

          def pretty_print_instance_variables
            (instance_variables - %i[@redis @get_inner_proxy @get_target]).sort
          end
        end
      end
    end
  end
end
