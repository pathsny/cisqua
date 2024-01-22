module Cisqua
  module Renamer
    class Response
      def initialize(type, destination, replacement: nil, junk: [], dups: [])
        @type = type
        @destination = destination
        @replacement = replacement
        @junk = junk
        @dups = dups
      end

      attr_reader :type, :destination, :replacement, :junk, :dups

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

        def replaced(destination, **)
          new(:resolved_duplicates_replaced, destination, **)
        end
      end
    end
  end
end
