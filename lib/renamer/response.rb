module Renamer
  class Response
    def initialize(type, destination)
      @type = type
      @destination = destination
    end

    attr_reader :type, :destination

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
    end
  end
end
