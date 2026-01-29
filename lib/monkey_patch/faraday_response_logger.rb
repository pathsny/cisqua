require 'faraday'

module CustomLoggerInitializer
  def initialize(app, _logger = nil, options = {})
    super(app, SemanticLogger['Faraday'], options)
  end
end

module Faraday
  class Response
    class Logger < Middleware
      prepend CustomLoggerInitializer
    end
  end
end
