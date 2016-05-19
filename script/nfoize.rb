# Build nfo files for existing shows for kodi/xbmc scraper integration

require 'rubygems'
require 'fileutils'
require File.expand_path('../../lib/libs', __FILE__)

abort "nfoize <source_path> <destination_path>" unless ARGV.length == 2

options = YAML.load_file(File.expand_path('../../data/options.yml', __FILE__))

destination = ARGV[1]
puts "moving done to #{destination}"
FileUtils.mkdir_p destination


dirs = Dir["#{ARGV.first}/*"].entries.select{|f| File.directory? f}
extensions = options[:scanner][:extensions].split.map{|e| ".#{e}"}
tuples = dirs.map {|d| [d, Dir["#{d}/*"].entries.find {|e| extensions.include? File.extname(e)}]}
files = tuples.map{|d,f| f}.compact

scan_queue = Queue.new
info_queue = Queue.new

scanner = Thread.new do
  files.each {|file| scan_queue << ed2k_file_hash(file) }
end

info_getter = Thread.new do
  anidb_api = Anidb.new options[:anidb]
  files.each do
    data = scan_queue.pop
    res = anidb_api.search_file(*data)[:file][:aid] rescue nil
    info_queue << [data.first, res]
  end
end

unknown = []    

nfo_creator = Thread.new do
  files.each do
    file, aid = info_queue.pop
    if aid
      dir = File.dirname(file)
      File.open("#{dir}/tvshow.nfo", 'w') {|f| f.write("aid=#{aid}")}
      FileUtils.mv dir, destination 
    else
      unknown << file
    end  
  end  
end  

info_getter.join
scanner.join
nfo_creator.join

puts "unknown files are #{unknown.inspect}"
puts "no files to scan in #{tuples.select {|_, b| b.nil?}.map(&:first).inspect}"
