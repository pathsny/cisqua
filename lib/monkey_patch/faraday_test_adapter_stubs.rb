require 'faraday'

module Faraday
  class Adapter
    class Test < Faraday::Adapter
      class Stubs
        def clear
          @stack.clear
          @consumed.clear
        end
      end
    end
  end
end
