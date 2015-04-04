require File.expand_path('../../rename_rules', __FILE__)
require 'fileutils'
require 'pathname'
require 'invariant'

class RenamerResponse
  def initialize(type)
    @type = type
  end
  
  attr_reader :type  

  class << self
    def unknown
      new(:unknown)
    end

    def success(destination)
      new(:success).tap do |inst|
        inst.define_singleton_method(:destination) { destination }
      end
    end
    
    def duplicate(duplicate_of)
      new(:duplicate).tap do |inst|
        inst.define_singleton_method(:destination) { duplicate_of }
      end  
    end      
  end  
end  

class Renamer
  def initialize(options)
    @options = options
  end

  attr_reader :options

  def try_process(work_item)
    file, info = work_item.file, work_item.info
    return RenamerResponse.unknown unless info
    location, path, name = generate_location(info)
    duplicate_of = is_duplicate_file(file, location, name)
    if duplicate_of
      return RenamerResponse.duplicate(duplicate_of)
    end    

    logger.debug "have to rename #{file} using #{path}/#{name}"
    create_location(location, info)
    ([file] + sub_files(file)).map do 
      |f| process_file(f, location, name)
    end  
    update_symlinks_for info[:anime], path, location if options[:create_symlinks]
    RenamerResponse.success(generate_destination(file, location, name))
  rescue
    logger.warn "error naming #{file} from #{info.inspect} with #{$!}"
  end

  def process_duplicate(work_item)
    assert options[:duplicate_location], "set duplicate_location to process duplicates"
    file, info = work_item.file, work_item.info
    path, name = generate_name_and_path(info)
    ([file] + sub_files(file)).map do |f| 
      process_file_unambiguous(options[:duplicate_location], f, name)
    end
  end  

  private
  def generate_name_and_path(info)
    generate_name(info).map{|n| escape(n)}
  end  

  def generate_location(info)
    path, name = generate_name_and_path(info)
    ["#{options[:output_location]}/#{path}", path, name]
  end

  def create_location(location, info)
    unless File.exist? location
      FileUtils.mkdir_p location
      File.open("#{location}/tvshow.nfo", 'w') {|f| f.write("aid=#{info[:file][:aid]}")} if options[:create_nfo_files]
    end
  end  

  def sub_files(file)
    extensions = options[:subtitle_extensions].split
    sub_files = extensions.map{|e| "#{file.chomp(File.extname(file))}.#{e}"}.select{|sf| File.exist?(sf)}
  end

  def is_duplicate_file(old_path, location, name)
    destination = generate_destination(old_path, location, name)
    return is_duplicate_destination(old_path, destination) ? destination : nil
  end

  def is_duplicate_destination(old_path, destination)
    File.exist?(destination) && destination != old_path
  end  

  def process_file(old_path, location, name)
    destination = generate_destination(old_path, location, name)
    assert !is_duplicate_destination(old_path, destination), "file #{old_path} is duplicated at #{destination}"

    # process_duplicate_file(options[:duplicate_location], old_path, new_name) and return if File.exist?(destination) && destination != old_path
    move_file old_path, destination
    logger.debug "moving #{old_path} to #{destination}"
  end

  def generate_destination(old_path, location, new_name_without_extension)
    new_name = "#{new_name_without_extension}#{File.extname(old_path)}"
    File.join(location, new_name)
  end

  # moves files to location using new_name. 
  # asserts that there is no existing file by that name
  # uses existing name if there is no new name
  # def process_file(location, old_path, new_name)

  # end

  # moves file to location using new_name. Adds suffixes if necessary to avoid
  # clashing with existing files.
  # uses existing name if there is no new name
  def process_file_unambiguous(location, old_path, new_name)
    FileUtils.mkdir_p(location)
    suffix = ''
    while File.exist?(destination = generate_destination(old_path, location, "#{new_name}#{suffix}"))
      suffix = ".#{suffix[1..-1].to_i + 1}"
    end
    move_file old_path, destination 
  end  

  def move_file(old_path, new_path)
    FileUtils.mv old_path, new_path
    if options[:symlink_source]
      relative = (Pathname.new new_path).relative_path_from (Pathname.new (File.dirname old_path))
      File.symlink(relative, old_path)
    end  
  rescue Exception => e
    logger.warn e.inspect
    puts e
  end  
  
  def update_symlinks_for(ainfo, folder, location)
    all_locations = [:movies, :incomplete_series, :complete_series, 
      :incomplete_other, :complete_other, :adult_location].map {|k| options[:create_symlinks][k] }.compact
    correct_location = decide_symlink_location(ainfo)
    incorrect_locations = all_locations.reject{|a| a == correct_location }
    incorrect_locations.each do |l|
      s = "#{l}/#{folder}"
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
    puts e
  end       

  def escape(name)
    valid_chars = %w(\w \. \- \[ \] \( \) &).join('')
    invalid_rg = "[^#{valid_chars}\s]"
    without_dups = name.gsub(Regexp.new("#{invalid_rg}(?![#{valid_chars}])"), '').
    gsub(Regexp.new("\\s#{invalid_rg}"), ' ').
    gsub(Regexp.new(invalid_rg), ' ').
    strip.squeeze(' ').
    sub(/\.$/,'')
  end
end