module Cisqua
  module Model
    module Saveable
      module Associations
        # Proxy for a set of ids tracked by some custom method

        class AssociatedIdsCustomProxy
          include Enumerable
          include SemanticLogger::Loggable

          include Enumerable

          def initialize(debug_info, &id_getter)
            @debug_info = debug_info
            @id_getter = id_getter
          end

          def __ids
            @id_getter.call
          end

          def include?(id)
            __ids.include?(id)
          end

          def to_set
            Set.new(__ids)
          end

          def to_a
            __ids
          end

          def length
            __ids.length
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
        end
      end
    end
  end
end
