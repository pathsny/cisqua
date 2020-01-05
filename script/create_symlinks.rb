#works on a series of files and creates the symlinks that would be created normally. assumes the nfo files exist with
#the anidb ids of anime. the argument passed in is the first folder to start from (to allow resuming)

require File.expand_path('../../lib/libs', __FILE__)
require File.expand_path('helpers/load_options', __dir__)
require 'rexml/document'
require 'optparse'

options_file = nil
mylist_location = nil
OptionParser.new do |opts|
  opts.banner = "Usage: create_symlinks -o <options file> -m <mylist_location>"
  opts.on("-oOPTIONS", "--options=OPTIONS", "location of options config") do |o|
    options_file = o
  end
  opts.on("-mMYLIST", "--mylist=MYLIST", "location of mylist") do |m|
    mylist_location = m
  end
end.parse!

options = ScriptOptions.load_options(options_file)
r_options = options[:renamer]

mylist = REXML::Document.new File.new("#{mylist_location}/mylist.xml")

all_folders = Dir["#{r_options[:output_location]}/**"].sort
first_folder = ARGV[1]
folders = first_folder ? all_folders.drop_while {|k| File.basename(k) != first_folder} : all_folders
abort "nothing to do" if folders.empty?

renamer = Renamer::Renamer.new(r_options)

folders.each do |f|
begin
  aid = File.read("#{f}/tvshow.nfo").match(/^aid=(\d+)$/)[1]
  axml = REXML::Document.new File.new("#{mylist_location}/anime/a#{aid}.xml")
  renamer.symlink(f, r_options[:adult_location], File.basename(f)) if r_options[:adult_location] && axml.elements["anime/seriesInfo/genres/genre[@id = '80']"]
  a_attrs = mylist.elements["myList/animeList/anime[@id = '#{aid}']"].attributes
  ainfo = {:type => a_attrs["type"],
  :ended => true,
  :completed => a_attrs["status"] == 'complete'}
  renamer.update_symlinks_for ainfo, File.basename(f), f
  Loggers::CreateLinks.debug { "#{f} has #{ainfo.inspect}" }
rescue
   Loggers::CreateLinks.error { "error working with #{f}" }
end
end

syms = r_options[:create_symlinks]
symlink_folders = [:movies, :incomplete_series, :complete_series, :incomplete_other, :complete_other].map { |k|
  Dir["#{syms[k]}/**"].map {|f| File.basename(f)}
}.reduce([]) {|acc, arr| acc | arr}
all_folder_names = all_folder.map {|f| File.basename(f)}
Loggers::CreateLinks.error { "something is wrong #{all_folder_names} does not map to #{symlink_folders}" } unless symlink_folders.size == all_folder_names.size && (symlink_folders & all_folder_names == symlink_folders)
