# console for debugging
require 'yaml'
require 'optparse'

C = Struct.new(:options_file, :options, :client).new

module Cisqua
  OptionParser.new do |opts|
    opts.banner = 'Usage: create_symlinks -o <options file> -m <mylist_location>'
    opts.on('-oOPTIONS', '--options=OPTIONS', 'location of options config') do |o|
      C.options_file = o
    end
  end.parse!
  require File.expand_path('../../lib/libs', __dir__)

  def logger
    return @logger if @logger

    AppLogger.log_file = File.join(DATA_FOLDER, 'log', 'console.log')
    @logger = SemanticLogger['AnidbConsole']
  end

  def self.r
    Dir[File.join(ROOT_FOLDER, 'lib', '**/*')].each do |f|
      load f unless File.directory?(f)
    end

    C.options = Options.load_options(C.options_file)
    api_options = C.options.api_client

    C.client = Net::AniDBUDP.new(
      *(%i[host port localport user pass nat].map { |k| api_options[:anidb][k] }),
    )
  end
end

# Cisqua.r
