require 'rubygems'
require 'lib/file_scanner'
require 'lib/anidb'

options = YAML.load_file(File.expand_path('../../options.yml', __FILE__))

destination = ARGV[1]
puts "moving done to #{destination}"


dirs = Dir["#{ARGV.first}/*"].entries.select{|f| File.directory? f}
extensions = %w(avi mpg mkv ogm mp4 flv wmv).map{|e| ".#{e}"}
tuples = dirs.map {|d| [d, Dir["#{d}/*"].entries.find {|e| extensions.include? File.extname(e)}]}
files = tuples.map{|d,f| f}.compact

scan_queue = Queue.new
info_queue = Queue.new

scanner = Thread.new do
  files.each {|file| scan_queue << ed2k_file_hash(file) }
end

info_getter = Thread.new do
  anidb_api = Anidb.new options[:anidb]
  anidb_api.connect
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
      puts "dir #{dir} is aid #{aid}"
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
