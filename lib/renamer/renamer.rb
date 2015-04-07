require_relative '../../rename_rules'
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

    # given a work_item indicating the existing file and given
    # a list of duplicates, processes all of them
    def process_duplicate_set(existing, duplicates)
      result = Renamer::DuplicateResolver.resolve(existing, duplicates)

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
end