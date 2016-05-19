# Main entry point for rename script. Checks with anidb, adds to mylist etc
require File.expand_path('../lib/libs', __FILE__)

Thread.abort_on_exception = true

options = YAML.load_file(File.expand_path('../data/options.yml', __FILE__))

files = file_list(options[:scanner])

scan_queue = Queue.new
info_queue = Queue.new
rename_queue = Queue.new

def while_queue_has_items(queue)
  until (item = queue.pop) == :end do
    yield item
  end  
end

def pipe_while_queue_has_items(source_queue, destination_queue)
  while_queue_has_items(source_queue) do |source_item|
    destination_queue << yield(source_item) 
  end
  destination_queue << :end  
end  

scanner = Thread.new do
  pipe_while_queue_has_items(scan_queue, info_queue) do |file|
    ed2k_file_hash(file).tap {|f, s, e| logger.debug "file #{f} has ed2k hash #{e}"}
  end
end

info_getter = Thread.new do
  anidb_api_klass = ARGV[0] == 'test_client' ? CachingAnidb : Anidb
  anidb_api = anidb_api_klass.new(options[:anidb])
  pipe_while_queue_has_items(info_queue, rename_queue) do |data|
    WorkItem.new(data.first, anidb_api.process(*data))
  end
end

rename_worker = Thread.new do
  renamer = Renamer::Renamer.new(options[:renamer])
  dups = Multimap.new
  success = {}
  files.each do 
    work_item = rename_queue.pop
    res = renamer.try_process(work_item)
    case res.type
    when :success
      logger.info "#{work_item.file} was successfully processed to #{res.destination}"
      success[res.destination] = work_item
    when :unknown
      logger.info "file #{work_item.file} is unknown #{"and moved to #{res.destination}" if res.destination}"
    when :duplicate
      logger.info "#{work_item.file} is a duplicate of #{res.destination}"
      dups[res.destination] = work_item
    end      
  end
  dups.each_association do |k, _|
    # rescan the duplicates unless we have it in the success map
    scan_queue << k unless success.has_key?(k)
  end 
  scan_queue << :end

  #resolve duplicates immideately for when we have all the info
  dups.each_association do |k, items|
    renamer.process_duplicate_set(
      WorkItem.new(k, success[k].info), items
    ) if success.has_key?(k)
  end

  #resolve duplicates as we get legacy info  
  while_queue_has_items(rename_queue) do |work_item|
    renamer.process_duplicate_set(work_item, dups[work_item.file])
  end  
end

files.each {|f| scan_queue << f }

[scanner, info_getter, rename_worker].each(&:join)

exit unless options[:clean_up_empty_dirs]
basedir = options[:scanner][:basedir]
abort('empty basedir') unless basedir

system "find /#{basedir} -type f -name \"tvshow.nfo\" -delete"

Dir["#{basedir}/**/*"].select { |d| File.directory? d }.sort{|a,b| b <=> a}.each {|d| Dir.rmdir(d) if Dir.entries(d).size ==  2} 
