require File.expand_path('../../lib/libs', __FILE__)
options = YAML.load_file(File.expand_path('../../options.yml', __FILE__))
require 'rexml/document'
r_options = options[:renamer]

mylist_location = ARGV.first
mylist = REXML::Document.new File.new("#{mylist_location}/mylist.xml")

def m_pattern(folder_name)
  extension = /\.[a-z0-9]+$/
  end_part = /\s- (?:Complete Movie|Part \d+ of \d+)(?:\s\[[\w&-\.]+\])? \[\(X-\d+\)\]/
  [Regexp.new("^#{Regexp.quote(folder_name)}#{end_part.source}#{extension.source}")] 
end

def s_pattern(folder_name)
  extension = /\.[a-z0-9]+$/
  end_part = /\s- episode \d+(?:\s\[[\w&-\.]+\])?/
  special_end = /\s- episode [A-Z](\d+)(?:\s\[[\w&-\.]+\])?\s\[\(XS-\d+-\1\)\]/
  [Regexp.new("^#{Regexp.quote(folder_name)}#{end_part.source}#{extension.source}"), 
    Regexp.new("^#{Regexp.quote(folder_name)}#{special_end.source}#{extension.source}")]
end

def m_pattern_fix(folder_name)
  []
end

def s_pattern_fix(folder_name)
  [Regexp.new("(^#{Regexp.quote(folder_name)}\\s- episode \\d+)((?:\\[[\\w&-\\.]+\\])?\\.[a-z0-9]+$)")]
end

Duplicates = {}
Unknown = []        
    
def try_fix(folder, movie)
  folder_name = File.basename(folder)
  files = Dir["#{folder}/*"].reject {|f| /^[^\.]*$/.match File.basename(f) || File.basename(f) == "tvshow.nfo"}
  fix_patterns = movie ? m_pattern_fix(folder_name) : s_pattern_fix(folder_name)
  files.each do |file|
    fix_patterns.each do |p|
      m = p.match File.basename(file)  
      if m
        destination = File.join(File.dirname(file), "#{m[1]} #{m[2]}")
        if File.exists? destination
          Duplicates[file] = destination
          puts "#{file} seems to be duplicate of #{destination}"
        else
          puts "renaming #{file} as #{destination}"
          FileUtils.mv file, destination
        end    
      end  
    end  
  end
  rescue
    puts "error working with #{folder} #{$!}"  
end

def test_names(folder, movie)
  folder_name = File.basename(folder)
  files = Dir["#{folder}/*"].reject do |file|
    /^[^\.]*$/.match(file) || File.basename(file) == "tvshow.nfo" || Duplicates.has_key?(file)
  end
  patterns = movie ? m_pattern(folder_name) : s_pattern(folder_name)
  files.each do |file| 
    unless patterns.any?{|p| p.match File.basename(file)}
      puts "do not know file #{file} using #{patterns.inspect}" 
      Unknown.push(file)
    end  
  end  
end


all_folders = Dir["#{r_options[:output_location]}/**"].sort
all_folders.each do |folder|
  aid = File.read("#{folder}/tvshow.nfo").match(/^aid=(\d+)$/)[1]
  movie = mylist.elements["myList/animeList/anime[@id = '#{aid}']"].attributes['type'] == 'Movie'
  try_fix(folder, movie)
  test_names(folder, movie)
end

File.open('duplicates.yml', 'w') {|f| f.write(Duplicates.to_yaml)}
File.open('unknown.yml', 'w') {|f| f.write(Unknown.to_yaml)}

puts Duplicates.inspect
puts Unknown.inspect

  