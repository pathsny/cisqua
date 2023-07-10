# console for debugging
require 'yaml'
require 'optparse'

options_file = nil
OptionParser.new do |opts|
  opts.banner = 'Usage: create_symlinks -o <options file> -m <mylist_location>'
  opts.on('-oOPTIONS', '--options=OPTIONS', 'location of options config') do |o|
    options_file = o
  end
end.parse!
require File.expand_path('../../lib/libs', __dir__)
options = ScriptOptions.load_options(options_file)

Client = Net::AniDBUDP.new(*(%i[host port localport user pass nat].map { |k| options[:anidb][k] }))
