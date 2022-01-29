require File.expand_path('libs', __dir__)
require 'resolv-replace'

class PostProcessor
  class << self
    def run(test_client, options)
      @test_client = test_client
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
          ed2k_file_hash(file).tap {
            |f, s, e| Loggers::PostProcessor.debug "file #{f} has ed2k hash #{e}"
          }
        end
      end

      info_getter = Thread.new do
        anidb_api_klass = @test_client ? CachingAnidb : Anidb
        anidb_api = anidb_api_klass.new(options[:anidb])
        pipe_while_queue_has_items(info_queue, rename_queue) do |data|
          WorkItem.new(data.first, anidb_api.process(*data))
        end
      end

      rename_worker = Thread.new do
        renamer = Renamer::Renamer.new(options[:renamer])
        dups = {}
        success = {}
        files.each do
          work_item = rename_queue.pop
          res = renamer.try_process(work_item)
          case res.type
          when :success
            Loggers::PostProcessor.info "MOVING \n\t#{work_item.file} ===>\n\t#{res.destination}"
            success[res.destination] = work_item
          when :unknown
            Loggers::PostProcessor.info "UNKNOWN file\n\t#{work_item.file}#{"  ===>\n\t#{res.destination}" if res.destination}"
          when :duplicate
            Loggers::PostProcessor.info "DUPLICATE file \n\t#{work_item.file} <=>\n\t#{res.destination}"
            dups[res.destination] = dups[res.destination] || []
            dups[res.destination].push(work_item)
          end
        end
        dups.each do |k, _|
          # rescan the duplicates unless we have it in the success map
          scan_queue << k unless success.has_key?(k)
        end
        scan_queue << :end

        #resolve duplicates immideately for when we have all the info
        dups.each do |k, items|
          renamer.process_duplicate_set(
            WorkItem.new(k, success[k].info), items
          ) if success.has_key?(k)
        end

        #resolve duplicates as we get legacy info
        while_queue_has_items(rename_queue) do |work_item|
          renamer.process_duplicate_set(work_item, dups[work_item.file])
        end

        renamer.post_rename_actions
      end

      files.each {|f| scan_queue << f }

      [scanner, info_getter, rename_worker].each(&:join)

      return unless options[:clean_up_empty_dirs]

      basedir = File.absolute_path(options[:scanner][:basedir], ROOT_FOLDER)
      raise 'empty basedir' unless basedir

      system "find /#{basedir} -type f -name \"tvshow.nfo\" -delete"

      Dir["#{basedir}/**/*"].select { |d| File.directory? d }.sort{|a,b| b <=> a}.each {|d| Dir.rmdir(d) if Dir.entries(d).size ==  2}
    end
  end
end
