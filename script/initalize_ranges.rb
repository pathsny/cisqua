# Main entry point for rename script. Checks with anidb, adds to mylist etc
require File.expand_path('../lib/libs', __dir__)
require File.join(Cisqua::ROOT_FOLDER, 'integration_spec', 'test_util')
require 'optparse'

module Cisqua
  class RangeInitializer
    def make_all(type)
      case type
      when :mylist
        MyList.anime_ids.each do |id|
          make_for_anime id
        end
      when :batch_data
        BatchData.latest(:all) do |bd|
          fids = bd.success_fids + bd.replacement_fids + bd.duplicate_fids
          aids = fids.map { |fid| Cisqua::AnimeFile.find(fid).anime.id }.uniq
          aids.each { |aid| bd.calculate_updates_hash(aid) }
        end

      end
    end

    def make_for_anime(aid)
      MyListRange.clear_record(aid)
      MyListRange.make_for_anime(aid)
    rescue StandardError => e
      puts "error processing #{aid} #{e}"
      raise
    end
  end

  script_options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: initialize_ranges'
    opts.on('-t', '--test', 'run for testing') do
      script_options[:test_mode] = true
    end
    opts.on('-s', '--start-redis', 'starts and stops redis server') do
      script_options[:start_redis] = true
    end
    opts.on('-m', '--mode TYPE', 'which type of data MyList or BatchData') do |type|
      type = type.to_sym
      assert(%i[mylist batch_data].include?(type.to_sym), "unknown mode #{type}")
      script_options[:type] = type
    end
  end.parse!

  Registry.options_file_override = script_options[:options_file]
  if script_options[:test_mode]
    TestUtil.prep_registry
  end
  registry = Registry.instance
  if script_options[:start_redis]
    RedisScripts.instance.with_redis(registry.options.redis.conf_path) do
      RangeInitializer.new.make_all(script_options[:type])
    end
  else
    RangeInitializer.new.make_all(script_options[:type])
  end
end
