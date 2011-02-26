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
  anidb_api.connect
  files.each do
    data = scan_queue.pop
    file = data.first
    info = anidb_api.search_file(*data)
    logger.debug "file #{file} identified as #{info.inspect}"
    
    if info
      logger.debug "adding #{file} to mylist"
      anidb_api.mylist_add(info[:fid])
    end  
    
    info_queue << [file, info]
  end
end

rename_worker = Thread.new do
  renamer = Renamer.new(options[:renamer])
  files.each do
    renamer.process(*info_queue.pop)
  end  
end

[scanner, info_getter, rename_worker].each(&:join)
