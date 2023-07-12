require_relative 'anidb'
require 'yaml'
require 'fileutils'

# caches anidb response. Only used while testing
class CachingAnidb
  def initialize(options)
    @anidb_api = Anidb.new options
    @cache_dir_path = File.expand_path(File.join(
      File.dirname(__FILE__),
      '..',
      'data',
      'udp_anime_info_cache',
    ))
  end

  def cache_file_path(ed2k)
    File.join(@cache_dir_path, "#{ed2k}.yml")
  end

  def process(*data)
    ed2k = data[2]
    f = cache_file_path(ed2k)
    if File.exist?(f)
      YAML.load_file(f)
    else
      FileUtils.mkdir_p(@cache_dir_path)
      @anidb_api.process(*data).tap do |info|
        File.write(f, info.to_yaml)
      end
    end
  end
end
