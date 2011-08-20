require File.expand_path('../lib/libs', __FILE__)

Thread.abort_on_exception = true

options = YAML.load_file(File.expand_path('../options.yml', __FILE__))

files = file_list(options[:scanner])

scan_queue = Queue.new
info_queue = Queue.new

scanner = Thread.new do
  files.each do |file| 
    scan_queue << ed2k_file_hash(file).tap {|f, s, e| logger.debug "file #{f} has ed2k hash #{e}"}
  end
end

info_getter = Thread.new do
  anidb_api = Anidb.new options[:anidb]
  files.each do
    data = scan_queue.pop
    info = anidb_api.process(*data)    
    info_queue << [data.first, info]
  end
end

rename_worker = Thread.new do
  renamer = Renamer.new(options[:renamer])
  files.each do
    renamer.process(*info_queue.pop)
  end  
end

[scanner, info_getter, rename_worker].each(&:join)

exit unless options[:clean_up_empty_dirs]
basedir = options[:scanner][:basedir]
abort('empty basedir') unless basedir

Dir["#{basedir}/**/*"].select { |d| File.directory? d }.sort{|a,b| b <=> a}.each {|d| Dir.rmdir(d) if Dir.entries(d).size ==  2 || (Dir.entries(d).size == 3 && Dir.entries(d).include? 'tvshow.nfo')} 
