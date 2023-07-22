# identify duplicate folders with the same show

require File.expand_path('../lib/libs', __dir__)
require 'optparse'

options_file = nil
OptionParser.new do |opts|
  opts.banner = 'Usage: duplicate_folders -o <options file>'
  opts.on('-oOPTIONS', '--options=OPTIONS', 'location of options config') do |o|
    options_file = o
  end
end.parse!
options = Options.load_options(options_file)

r_options = options[:renamer]

output_location = File.absolute_path(r_options[:output_location], ROOT_FOLDER)
all_folders = Dir["#{output_location}/**"]
aid_folder_hash = all_folders.group_by do |f|
  match_data = File.read("#{f}/tvshow.nfo").match(/^aid=(\d+)\s*$/)
  raise "did not match for #{f}" unless match_data

  match_data[1]
end

logger = SemanticLogger['Duplicates']
aid_folder_hash.each do |_aid, folders|
  logger.info { "duplicate #{folders.inspect}" } if folders.length > 1
end
