# console for debugging
require 'yaml'
require 'optparse'

C = Struct.new(:options_file, :test_mode, :registry).new

module Cisqua
  OptionParser.new do |opts|
    opts.banner = 'Usage: create_symlinks -o <options file> -m <mylist_location>'
    opts.on('-oOPTIONS', '--options=OPTIONS', 'location of options config') do |o|
      C.options_file = o
    end
    opts.on('-t', '--test_mode', 'whether to start in test mode') do
      C.test_mode = true
    end
  end.parse!
  require File.expand_path('../../lib/libs', __dir__)

  def logger
    return @logger if @logger

    AppLogger.log_file = File.join(DATA_FOLDER, 'log', 'console.log')
    @logger = SemanticLogger['AnidbConsole']
  end
end

def r
  Dir[File.join(Cisqua::ROOT_FOLDER, 'lib', '**/*')].each do |f|
    load f unless File.directory?(f)
  end

  registry_klass = Cisqua::Registry

  registry_klass.clear
  registry_klass.options_file_override = C.options_file
  registry_klass.test_mode_override = C.test_mode
  C.registry = registry_klass.instance
end

r
