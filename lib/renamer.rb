require File.expand_path('../../rename_rules', __FILE__)
require 'fileutils'
require 'pathname'
require 'invariant'

module Renamer
  class Response
    def initialize(type, destination)
      @type = type
      @destination = destination
    end
    
    attr_reader :type, :destination  

    class << self
      def unknown(destination)
        new(:unknown, destination)
      end

      def success(destination)
        new(:success, destination)
      end
      
      def duplicate(duplicate_of)
        new(:duplicate, duplicate_of)
      end      
    end  
  end  

  class Renamer
    def initialize(options)
      @options = options
      @mover = VideoFileMover.new(options)
      @name_generator = NameGenerator.new(method(:generate_name))
    end

    attr_reader :options

    def try_process(work_item)
      file, info = work_item.file, work_item.info
      unless info
        response = @mover.process(options[:unknown_location], file,
          :unambiguous => true
        ) if options[:unknown_location]
        assert(response.type == :success, "moving unkwown files should not fail")
        return Response.unknown(response.destination)
      end

      location, path, name = generate_location(info)
      @mover.process(location, file, :new_name => name).tap do |response|
        if response.type == :success
          ensure_nfo(location, info)
          update_symlinks_for(info[:anime], path, location) if options[:create_symlinks]
        end
      end
    rescue
      logger.warn "error naming #{file} from #{info.inspect} with #{$!}"
      raise
    end

    def process_duplicate(work_item)
      assert options[:duplicate_location], "set duplicate_location to process duplicates"
      path, name = @name_generator.generate_name_and_path(work_item.info)
      @mover.process(options[:duplicate_location], work_item.file, 
        :new_name => name, 
        :unambiguous => true
      )
    end  

    private
    def generate_location(info)
      path, name = @name_generator.generate_name_and_path(info)
      [File.join(options[:output_location], path), path, name]
    end

    def ensure_nfo(location, info)
      nfo_path = File.join(location, 'tvshow.nfo')
      File.open(nfo_path, 'w') do |f| 
        f.write("aid=#{info[:file][:aid]}")
      end if !File.exist?(nfo_path) && options[:create_nfo_files]
    end

    def update_symlinks_for(ainfo, folder, location)
      all_locations = [:movies, :incomplete_series, :complete_series, 
        :incomplete_other, :complete_other, :adult_location].map {|k| options[:create_symlinks][k] }.compact
      correct_location = decide_symlink_location(ainfo)
      incorrect_locations = all_locations.reject{|a| a == correct_location }
      incorrect_locations.each do |l|
        s = File.join(l, folder)
        if File.symlink?(s)
          File.unlink(s)
          logger.info "deleting symlink #{s} to #{location}" 
        end  
      end  
      if correct_location && !File.symlink?("#{correct_location}/#{folder}")
        symlink(location, correct_location, folder)
        logger.debug "symlinking #{location} to #{correct_location}/#{folder}" 
      end  
    end
    
    def decide_symlink_location(ainfo)
      symlink_locations = options[:create_symlinks]
      return symlink_locations[:adult_location] if ainfo[:is_18_restricted] == "1" 
      return symlink_locations[:movies] if ainfo[:type] == "Movie"
      type = ["Web", "TV Series", "OVA", "TV Special"].include?(ainfo[:type]) ? :series : :other
      status = ainfo[:ended] && ainfo[:completed] ? :complete : :incomplete
      symlink_locations["#{status}_#{type}".to_sym]
    end
    
    def symlink(source, dest, name)
      src_path = Pathname.new source
      dest_path = Pathname.new dest
      relative = src_path.relative_path_from dest_path
      FileUtils.mkdir_p(dest_path) unless File.exist?(dest_path)
      File.symlink(relative, File.join(dest,name))
    rescue Exception => e
      logger.warn e.inspect
      raise
    end       
  end

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

  class NameGenerator
    def initialize(make_name)
      @make_name = make_name
    end
      
    def generate_name_and_path(info)
      @make_name[info].map{|n| escape(n)}
    end

    private
    # ensure that a name can be used on a filesystem
    def escape(name)
      valid_chars = %w(\w \. \- \[ \] \( \) &).join('')
      invalid_rg = "[^#{valid_chars}\s]"
      name.gsub(Regexp.new("#{invalid_rg}(?![#{valid_chars}])"), '').
      gsub(Regexp.new("\\s#{invalid_rg}"), ' ').
      gsub(Regexp.new(invalid_rg), ' ').
      strip.squeeze(' ').
      sub(/\.$/,'')
    end
  end  
end