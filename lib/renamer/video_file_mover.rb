module Renamer
  class VideoFileMover
    def initialize(options)
      @options = options
    end

    # moves file to location. 
    # options can be configured to create a new_name at destination or 
    # symlink back to source.
    def process(location, old_path, options = {})
      logger.debug "process #{old_path} to #{location} with #{options}"
      destination = generate_destination(old_path, location, options)
      if (is_duplicate_destination(old_path, destination))
        return Response.duplicate(destination)
      end  
      FileUtils.mkdir_p(location)
      move_file(old_path, destination, options)
      @options[:subtitle_extensions].split.each do |ext|
        sub_path = swap_extension(old_path, ext)
        move_file(sub_path, swap_extension(destination, ext), options) if 
          File.exist?(sub_path)
      end
      Response.success(destination)
    end

    private

    def generate_destination(old_path, location, options)
      ext = File.extname(old_path)
      new_name = options[:new_name] ? 
        options[:new_name] : File.basename(old_path, '.*')
      suffix = ''  
      mk_dest = lambda { File.join(location, new_name + suffix + ext) }
      destination = mk_dest.call
      while options[:unambiguous] && is_duplicate_destination(old_path, destination)
        suffix = ".#{suffix[1..-1].to_i + 1}"
        destination = mk_dest.call
      end
      destination
    end

    def swap_extension(file, ext)
      file.chomp(File.extname(file)) + ".#{ext}"
    end  
    
    def is_duplicate_destination(old_path, destination)
      File.exist?(destination) && destination != old_path
    end  

      # moves a file from `old_path` to `new_path`.
      # Optionally generates a symlink back to old_path if specified with options
    def move_file(old_path, new_path, options)
      FileUtils.mv old_path, new_path
      if @options[:symlink_source] && old_path != new_path
        relative = (Pathname.new new_path).relative_path_from (Pathname.new (File.dirname old_path))
        File.symlink(relative, old_path)
      end  
    end  
  end    
end