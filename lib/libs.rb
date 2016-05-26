require 'yaml'
require 'thread'
require 'multimap'
require 'logger'
require_relative '../external/lru_hash'

Dir[File.join(File.dirname(__FILE__), '**/*.rb')].each do |f| 
  require f unless f == __FILE__
end

def create_logger(logfile = File.expand_path('../../log/anidb.log', __FILE__)) 
  $logger = Logger.new(logfile).tap {|l| l.level = $DEBUG ? Logger::DEBUG : Logger::INFO}
end

def logger
  create_logger unless defined?($logger)
  $logger
end

