module Cisqua
  module Renamer
    class Response
      def initialize(type, destination, work_item = nil)
        @type = type
        @destination = destination
        @work_item = work_item
      end

      attr_reader :type, :destination, :work_item

      class << self
        def unknown(destination)
          new(:unknown, destination)
        end

        def success(destination)
          new(:success, destination)
        end

        def duplicate(duplicate_of)
          new(:duplicate, duplicate_of)
        end

        def unchanged(destination, **)
          new(:resolved_duplicates_unchanged, destination, **)
        end

        def replaced(work_item, destination, **)
          new(:resolved_duplicates_replaced, destination, work_item, **)
        end
      end
    end
  end
end
