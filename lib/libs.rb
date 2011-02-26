require 'yaml'
require 'thread'
require File.expand_path('../anidb', __FILE__)
require File.expand_path('../file_list', __FILE__)
require File.expand_path('../file_scanner', __FILE__)
require File.expand_path('../renamer', __FILE__)

require 'logger'

def logger
  @logger ||= Logger.new('anidb.log').tap {|l| l.level = $DEBUG ? Logger::DEBUG : Logger::INFO}
end  
