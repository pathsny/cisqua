#works on a series of files and creates the symlinks that would be created normally. assumes the nfo files exist with
#the anidb ids of anime. the argument passed in is the first folder to start from (to allow resuming)
require File.expand_path('../../lib/libs', __FILE__)
options = YAML.load_file(File.expand_path('../../options.yml', __FILE__))
r_options = options[:renamer]

all_folders = Dir["#{r_options[:output_location]}/**"]
first_folder = ARGV.first
folders = first_folder ? all_folders.drop_while {|k| File.basename(k) != first_folder} : all_folders
abort "nothing to do" if folders.empty?


client = Anidb.new(options[:anidb])
renamer = Renamer.new(r_options)

folders.each do |f|
  aid = File.read("#{f}/tvshow.nfo").match(/^aid=(\d+)$/)[1]
  data = client.anime(aid)[:anime]
  data[:completed] = client.__send__(:create_mylist_data, aid, data[:episodes].to_i).complete?
  
  folder = File.basename f
  File.symlink(f, "#{r_options[:adult_location]}/#{folder}") if r_options[:adult_location] && data[:is_18_restricted] == "1" && !File.symlink?("#{r_options[:adult_location]}/#{folder}")
  renamer.update_symlinks_for data, folder, f
  puts "processed #{f}"
end

syms = r_options[:create_symlinks]
symlink_folders = [:movies, :incomplete_series, :complete_series, :incomplete_other, :complete_other].map { |k|
  Dir["#{syms[k]}/**"].map {|f| File.basename(f)}
}.reduce([]) {|acc, arr| acc | arr}
all_folder_names = all_folders.map {|f| File.basename(f)}
puts "something is wrong #{all_folder_names} does not map to #{symlink_folders}" unless symlink_folders.size == all_folder_names.size && (symlink_folders & all_folder_names == symlink_folders)
