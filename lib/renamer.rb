require File.expand_path('../../rename_rules', __FILE__)
require 'fileutils'
require 'pathname'

class Renamer
  def initialize(options)
    @options = options
  end

  attr_reader :options  

  def process(file, info)
    logger.info "file #{file} is unknown" and return unless info
    puts "file #{file} has info #{info.inspect}"
    path, name = generate_name(info).map{|n| escape(n)}
    logger.debug "have to rename #{file} using #{path}/#{name}"
    location = create_location(path, info)

    ([file] + sub_files(file)).map{|f| process_file(f, location, name)}
    update_symlinks_for info[:anime], path, location if options[:create_symlinks]
  rescue
    logger.warn "error naming #{file} from #{info.inspect} with #{$!}"
  end

  def create_location(path, info)
    "#{options[:output_location]}/#{path}".tap do |location|
      unless File.exist? location
        FileUtils.mkdir_p location
        File.open("#{location}/tvshow.nfo", 'w') {|f| f.write("aid=#{info[:file][:aid]}")} if options[:create_nfo_files]
      end
    end  
  end  

  def sub_files(file)
    extensions = options[:subtitle_extensions].split
    sub_files = extensions.map{|e| "#{file.chomp(File.extname(file))}.#{e}"}.select{|sf| File.exist?(sf)}
  end  

  def process_file(old_path, location, new_name_without_extension)
    new_name = "#{new_name_without_extension}#{File.extname(old_path)}"
    destination = "#{location}/#{new_name}"

    process_duplicate_file(options[:duplicate_location], old_path, new_name) and return if File.exist?(destination) && destination != old_path
    move_file old_path, destination
    logger.info "moving #{old_path} to #{destination}"
  end

  def process_duplicate_file(location, old_path, new_name)
    FileUtils.mkdir_p location
    logger.info "cannot move #{old_path} to #{new_name}. Duplicate File already exists"
    prefix = ''
    while File.exist? "#{location}/#{new_name}#{prefix}"
      prefix = ".#{prefix[1..-1].to_i || 1}"
    end
    move_file old_path, "#{location}/#{new_name}#{prefix}"
    true   
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
      logger.info "symlinking #{location} to #{correct_location}/#{folder}" 
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