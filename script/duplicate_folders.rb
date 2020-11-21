# identify duplicate folders with the same show

require File.expand_path('../../lib/libs', __FILE__)
require File.expand_path('helpers/load_options', __dir__)
require 'optparse'

options_file = nil
OptionParser.new do |opts|
  opts.banner = "Usage: duplicate_folders -o <options file> -m <mylist_location>"
  opts.on("-oOPTIONS", "--options=OPTIONS", "location of options config") do |o|
    options_file = o
  end
end.parse!
options = ScriptOptions.load_options(options_file)

r_options = options[:renamer]

all_folders = Dir["#{r_options[:output_location]}/**"].sort
aid_folder_hash = all_folders.group_by do |f|
  match_data = File.read("#{f}/tvshow.nfo").match(/^aid=(\d+)$/)
  raise "did not match for #{f}" unless match_data
  match_data[1]
end
aid_folder_hash.each {
  |aid, folders| Loggers::Duplicates.info { "duplicate #{folders.inspect}" } if folders.length > 1
}
