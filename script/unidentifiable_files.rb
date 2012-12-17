require File.expand_path('../../lib/libs', __FILE__)
options = YAML.load_file(File.expand_path('../../options.yml', __FILE__))
require 'rexml/document'
r_options = options[:renamer]

mylist_location = ARGV.first
mylist = REXML::Document.new File.new("#{mylist_location}/mylist.xml")

def m_pattern(folder_name)
  extension = /\.[a-z0-9]+$/
  end_part = /\s- (?:Complete Movie|Part \d+ of \d+)(?:\s\[[\w-]+\])? \[\(X-\d+\)\]/
  [Regexp.new("^#{folder_name}#{end_part.source}#{extension.source}")] 
end
def s_pattern(folder_name)
  extension = /\.[a-z0-9]+$/
  end_part = /\s- episode \d+(?:\s\[[\w-]+\])?/
  special_end = /\s- episode [A-Z](\d+)(?:\s\[[\w-]+\])?\s\[\(XS-\d+-\1\)\]/
  [Regexp.new("^#{folder_name}#{end_part.source}#{extension.source}"), 
    Regexp.new("^#{folder_name}#{special_end.source}#{extension.source}")]
end    

all_folders = Dir["#{r_options[:output_location]}/**"].sort
all_folders.each do |folder|
  aid = File.read("#{folder}/tvshow.nfo").match(/^aid=(\d+)$/)[1]
  folder_name = File.basename(folder)
  files = Dir["#{folder}/*"].map {|a| File.basename(a)}.reject {|f| /^[^\.]*$/.match f} - ["tvshow.nfo"]
  movie = mylist.elements["myList/animeList/anime[@id = '#{aid}']"].attributes['type'] == 'Movie'
  patterns = movie ? m_pattern(folder_name) : s_pattern(folder_name)
  files.each do |file| 
    puts "do not know file #{file} of #{folder} using #{patterns.inspect}" unless patterns.any?{|p| p.match file}
  end  
end

  