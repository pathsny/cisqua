require 'yaml'
require 'thread'
require 'multimap'
require 'loggers'
require_relative '../external/lru_hash'

Dir[File.join(File.dirname(__FILE__), '**/*.rb')].each do |f| 
  require f unless f == __FILE__
end

def create_logger 
  $logger = Logging.logger.root
end

def logger
  create_logger unless defined?($logger)
  $logger
end

