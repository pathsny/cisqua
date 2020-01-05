# identifies duplicate files and unknown files

require 'rexml/document'
require 'optparse'
require File.expand_path('helpers/load_options', __dir__)
require File.expand_path('../../lib/libs', __FILE__)
options_file = nil
mylist_location = nil
OptionParser.new do |opts|
  opts.banner = "Usage: console -n anidb"
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

def m_pattern(folder_name)
  extension = /\.[A-Za-z0-9]+$/
  end_part = /\s- (?:Complete Movie|Part \d+ of \d+|[^\[]*)(?:\s\[[\w&-\.~\s!=]+\])? \[\(XS?-\d+(?:-\d+)?\)\]/
  [Regexp.new("^#{Regexp.quote(folder_name)}\.?#{end_part.source}#{extension.source}")]
end

def s_pattern(folder_name)
  extension = /\.[A-Za-z0-9]+$/
  end_part = /\s- episode \d+(?:\s\[[\w&-\.~\s!=]+\])?/
  special_end = /\s- episode [A-Z](\d+)(?:\s\[[\w&-\.~\s!=]+\])?\s\[\(XS-\d+-\1\)\]/
  f = Regexp.quote(folder_name)
  [Regexp.new("^#{f}\\.?#{end_part.source}#{extension.source}"),
    Regexp.new("^#{f}\\.?#{special_end.source}#{extension.source}"),
    Regexp.new("^#{f}\\.?\\s- episode \\d+-\\d+(?:\\s\\[[\\w&-\\.~\\s!]+\\])?#{extension.source}")
    ]
end

def m_pattern_fix(folder_name)
  []
end

def s_pattern_fix(folder_name)
  f = Regexp.quote(folder_name)
  [{ :r => Regexp.new("(^#{f}\\.?\\s- episode \\d+)((?:\\[[\\w&-\\.~\\s!=]+\\])?\\.[A-Za-z0-9]+$)"),
    :p => [1,' ',2]
  }, { :r => Regexp.new("(^#{f}\\.?\\s- episode [A-Z](\\d+))((?:\\[[\\w&-\\.~\\s!=]+\\])?\s\\[\\(XS-\\d+-\\2\\)\\]\\.[A-Za-z0-9]+$)"),
    :p => [2,' ',3]
  }, {
    :r => Regexp.new("(^#{f}\\.?\\s- episode \\d+)\s(\\.[A-Za-z0-9]+$)"),
    :p => [1,2]
  }]
end

Duplicates = {}
Unknown = []

def try_fix(folder, movie)
  folder_name = File.basename(folder)
  files = Dir["#{folder}/*"].reject {|f| /^[^\.]*$/.match File.basename(f) || File.basename(f) == "tvshow.nfo"}
  fix_patterns = movie ? m_pattern_fix(folder_name) : s_pattern_fix(folder_name)
  files.each do |file|
    fix_patterns.each do |p|
      m = p[:r].match File.basename(file)
      if m
        new_name = p[:p].map{|part| part.is_a?(Integer) ? m[part] : part }.join('')
        destination = File.join(File.dirname(file), new_name)
        if File.exists? destination
          Duplicates[file] = destination
          Loggers::BadFiles.debug {"#{file} seems to be duplicate of #{destination}" }
        else
          Loggers::BadFiles.info { "renaming #{file} as #{destination}" }
          FileUtils.mv file, destination
        end
      end
    end
  end
  rescue
    Loggers::BadFiles.error { "error working with #{folder} #{$!}" }
end

def test_names(folder, movie)
  folder_name = File.basename(folder)
  files = Dir["#{folder}/*"].reject do |file|
    /^[^\.]*$/.match(file) || File.basename(file) == "tvshow.nfo" || Duplicates.has_key?(file)
  end
  patterns = movie ? m_pattern(folder_name) : s_pattern(folder_name)
  files.each do |file|
    unless patterns.any?{|p| p.match File.basename(file)}
      Loggers::BadFiles.debug { "do not know file #{file} using #{patterns.inspect}" }
      Unknown.push(file)
    end
  end
end


all_folders = Dir["#{r_options[:output_location]}/**"].sort
all_folders.each do |folder|
  aid = File.read("#{folder}/tvshow.nfo").match(/^aid=(\d+)$/)[1]
  movie = mylist.elements["myList/animeList/anime[@id = '#{aid}']"].attributes['type'] == 'Movie'
  # try_fix(folder, movie)
  test_names(folder, movie)
end

File.open('duplicates.yml', 'w') {|f| f.write(Duplicates.to_yaml)}
File.open('unknown.yml', 'w') {|f| f.write(Unknown.to_yaml)}

Loggers::BadFiles.info { Duplicates.inspect }
Loggers::BadFiles.info { Unknown.inspect }
