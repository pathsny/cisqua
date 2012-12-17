require File.expand_path('../../lib/libs', __FILE__)
options = YAML.load_file(File.expand_path('../../options.yml', __FILE__))
require 'rexml/document'
r_options = options[:renamer]

all_folders = Dir["#{r_options[:output_location]}/**"].sort
aid_folder_hash = all_folders.group_by {|f| File.read("#{f}/tvshow.nfo").match(/^aid=(\d+)$/)[1]}
aid_folder_hash.each {|aid, folders| puts "duplicate #{folders.inspect}" if folders.length > 1}