module Cisqua
  module Model
    module Saveable
      module Associations
        # Proxy objects must manage their own cache against the redis set

        class AssociatedObjectsProxy
          include Enumerable

          def initialize(id_proxy, get_instance, get_attribute, debug_info)
            @debug_info = debug_info
            @ids = id_proxy
            @get_instance = get_instance
            @get_attribute = get_attribute
          end

          attr_reader :redis_set_key, :ids

          def get(id)
            return nil unless @ids.include?(id)

            @get_instance.call(id)
          end

          def [](id)
            get(id)
          end

          def to_a
            @ids.map { |id| get(id) }
          end

          def length
            @ids.length
          end

          def each(&)
            return to_enum(:each) unless block_given?

            to_a.each(&)
          end

          def empty?
            length.zero?
          end

          def add(object, transaction: nil)
            id = @get_attribute.call(object)
            @ids.add_many(transaction:, ids: [id])
          end

          def remove(object, transaction: nil)
            id = @get_attribute.call(object)
            @ids.remove_many(transaction:, ids: [id])
          end

          def last
            last_id = @ids.last
            get(last_id)
          end

          alias member? include?
          alias size length

          def pretty_print_instance_variables
            (instance_variables - %i[@ids @get_instance @get_attribute]).sort
          end
        end
      end
    end
  end
end
