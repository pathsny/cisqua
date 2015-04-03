require_relative 'anidb'
require 'yaml'

#caches anidb response. Only used while testing
class CachingAnidb
  def initialize(options)
    @anidb_api = Anidb.new options 
  end

  def cache_file_path(ed2k)
    File.expand_path(File.join(File.dirname(__FILE__), '..', 'data', "#{ed2k}.yml"))
  end  

  def process(*data)
    ed2k = data[2]
    f = cache_file_path(ed2k)
    if !File.exist?(f)
      @anidb_api.process(*data).tap do |info| 
        File.open(f, 'w') {|file| file.write(info.to_yaml)} 
      end  
    else
      YAML.load_file(f)
    end
  end  
end  