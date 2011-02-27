require 'yaml'
require 'thread'
require File.expand_path('../anidb', __FILE__)
require File.expand_path('../file_list', __FILE__)
require File.expand_path('../file_scanner', __FILE__)
require File.expand_path('../renamer', __FILE__)
require File.expand_path('../../external/lru_hash', __FILE__)

require 'logger'

def create_logger(logfile = File.expand_path('../../anidb.log', __FILE__))  
  @logger = Logger.new(logfile).tap {|l| l.level = $DEBUG ? Logger::DEBUG : Logger::INFO}
end

def logger
  create_logger unless @logger
  @logger
end

