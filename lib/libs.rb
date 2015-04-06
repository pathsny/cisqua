require 'yaml'
require 'thread'
require 'multimap'
require_relative 'work_item'
require_relative 'anidb'
require_relative 'caching_anidb'
require_relative 'file_list'
require_relative 'file_scanner'
require_relative 'renamer'
require_relative 'mylist_data'
require_relative '../external/lru_hash'


require 'logger'

def create_logger(logfile = File.expand_path('../../anidb.log', __FILE__))  
  @logger = Logger.new(logfile).tap {|l| l.level = $DEBUG ? Logger::DEBUG : Logger::INFO}
end

def logger
  create_logger unless @logger
  @logger
end

