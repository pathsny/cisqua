require File.expand_path('../lib/libs', __FILE__)

Thread.abort_on_exception = true

options = YAML.load_file(File.expand_path('../options.yml', __FILE__))

files = file_list(options[:scanner])

scan_queue = Queue.new
info_queue = Queue.new
rename_queue = Queue.new

def while_queue_has_items(queue)
  item = queue.pop
  until item == :end do
    yield item
    item = queue.pop
  end  
end  

scanner = Thread.new do
  while_queue_has_items(scan_queue) do |file|
    info_queue << ed2k_file_hash(file).tap {|f, s, e| logger.debug "file #{f} has ed2k hash #{e}"}
  end
  info_queue << :end
end

info_getter = Thread.new do
  anidb_api_klass = ARGV[0] == 'test_client' ? CachingAnidb : Anidb
  anidb_api = anidb_api_klass.new(options[:anidb])
  while_queue_has_items(info_queue) do |data|
    info = anidb_api.process(*data)    
    rename_queue << [data.first, info]
  end
  rename_queue << :end  
end

rename_worker = Thread.new do
  renamer = Renamer.new(options[:renamer])
  while_queue_has_items(rename_queue) do |file, data|
    renamer.process(file, data)
  end  
end

files.each {|f| scan_queue << f }
scan_queue << :end

[scanner, info_getter, rename_worker].each(&:join)

exit unless options[:clean_up_empty_dirs]
basedir = options[:scanner][:basedir]
abort('empty basedir') unless basedir

system "find /#{basedir} -type f -name \"tvshow.nfo\" -delete"

Dir["#{basedir}/**/*"].select { |d| File.directory? d }.sort{|a,b| b <=> a}.each {|d| Dir.rmdir(d) if Dir.entries(d).size ==  2} 
