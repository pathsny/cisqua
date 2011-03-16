require File.expand_path('../../rename_rules', __FILE__)
require 'fileutils'

class Renamer
  def initialize(options)
    @options = options
  end

  attr_reader :options  

  def process(file, info)
    logger.info "file #{file} is unknown" and return unless info

    path, name = generate_name(info).map{|n| escape(n)}
    logger.debug "have to rename #{file} using #{path}/#{name}"
    location = create_location(path, info)

    ([file] + sub_files(file)).map{|f| move_file(f, location, name)}
  rescue
    logger.warn "error naming #{file} from #{info.inspect}"
  end

  def create_location(path, info)
    "#{options[:incomplete_location]}/#{path}".tap do |location|
      unless File.exists? location
        FileUtils.mkdir_p location
        File.open("#{location}/tvshow.nfo", 'w') {|f| f.write("aid=#{info[:file][:aid]}")} if options[:create_nfo_files]
      end
    end  
  end  

  def sub_files(file)
    extensions = options[:subtitle_extensions].split
    sub_files = extensions.map{|e| "#{file.chomp(File.extname(file))}.#{e}"}.select{|sf| File.exists?(sf)}
  end  

  def move_file(old_name, location, new_name_without_extension)
    new_name = "#{new_name_without_extension}#{File.extname(old_name)}"
    destination = "#{location}/#{new_name}"

    move_duplicate_file(options[:duplicate_location], old_name, new_name) and return if File.exists?(destination) && destination != old_name

    FileUtils.mv old_name, destination
    logger.info "moving #{old_name} to #{destination}"
  end  

  def move_duplicate_file(location, old_name, new_name)
    FileUtils.mkdir_p location
    logger.info "cannot move #{old_name} to #{new_name}. Duplicate File already exists"
    prefix = ''
    while File.exists? "#{location}/#{new_name}#{prefix}"
      prefix = ".#{prefix[1..-1].to_i || 1}"
    end
    FileUtils.mv old_name, "#{location}/#{new_name}#{prefix}"
    true   
  end  

  def escape(name)
    name.gsub(/[^\w\s\.\-\[\]\(\)&]/, '')
  end    
end