module Cisqua
  class ImportError < StandardError
    attr_reader :data, :inner_error

    def initialize(message, data: nil, inner_error: nil)
      super(message)
      if inner_error.is_a? ImportError
        @data = inner_error.data.merge(data)
        @inner_error = inner_error.inner_error
      else
        @data = data
        @inner_error = inner_error
      end
    end
  end
end
