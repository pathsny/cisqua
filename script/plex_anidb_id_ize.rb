# Build anidb.id for existing shows for plex integration from kodi integration files

require File.expand_path('../lib/libs', __dir__)
require File.expand_path('helpers/load_options', __dir__)
require 'optparse'

options_file = nil
OptionParser.new do |opts|
  opts.banner = 'Usage: plex_anidb_id_ize -o <options file>'
  opts.on('-oOPTIONS', '--options=OPTIONS', 'location of options config') do |o|
    options_file = o
  end
end.parse!
options = ScriptOptions.load_options(options_file)

r_options = options[:renamer]

output_location = File.absolute_path(r_options[:output_location], ROOT_FOLDER)
Loggers::PlexAnidbIdize.info { "processing files in #{output_location}" }
unless r_options[:create_anidb_id_files]
  Loggers::PlexAnidbIdize.info { 'Nothing to do since create_anidb_id_files is false' }
  exit
end

all_folders = Dir["#{output_location}/**"].sort
all_folders.each do |f|
  match_data = File.read("#{f}/tvshow.nfo").match(/^aid=(\d+)\s*$/)
  raise "did not match for #{f}" unless match_data

  idfile_path = File.join(f, 'anidb.id')
  next if File.exist?(idfile_path)

  File.open(idfile_path, 'w') do |f|
    f.write("#{match_data[1]}\n")
  end
end
