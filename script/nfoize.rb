# Build nfo files for existing shows for kodi/xbmc scraper integration

require 'rubygems'
require 'fileutils'
require 'optparse'
require File.expand_path('helpers/load_options', __dir__)
require File.expand_path('../../lib/libs', __FILE__)

options_file = nil
source_path = null
destination = null
OptionParser.new do |opts|
  opts.banner = "Usage: nfoize -o <options file> -m <mylist_location>"
  opts.on("-oOPTIONS", "--options=OPTIONS", "location of options config") do |o|
    options_file = o
  end
  opts.on("-sSOURCE", "--source=SOURCE", "location of source path") do |source|
    source_path = source
  end
  opts.on("-dDESTINATION", "--dest=DESTINATION", "location of source path") do |dest|
    destination = dest
  end
end.parse!
options = ScriptOptions.load_options(options_file)

raise 'incorrect usage unless' source_path && destination

Loggers::NFOize.info { "moving done to #{destination}" }
FileUtils.mkdir_p destination


dirs = Dir["#{source_path}/*"].entries.select{|f| File.directory? f}
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

Loggers::NFOize.info { "unknown files are #{unknown.inspect}" }
Loggers::NFOize.info { "no files to scan in #{tuples.select {|_, b| b.nil?}.map(&:first).inspect}" }
