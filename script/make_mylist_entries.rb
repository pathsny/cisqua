# update the redis db to create mylist_anime_entries
require File.expand_path('../lib/libs', __dir__)
require 'optparse'

module Cisqua
  class MakeMyListEntries
    def run
      Registry.instance.redis.smembers('mylist:animes').each do |aid|
        MyListAnimeEntry.upsert(aid)
      end
    end
  end
end

# script_options = {}
# OptionParser.new do |opts|
#   opts.on('-s', '--start-redis', 'starts and stops redis server') do
#     script_options[:start_redis] = true
#   end
# end.parse!

# Registry.options_file_override = script_options[:options_file]
# if script_options[:test_mode]
#   TestUtil.prep_registry
# end
# Registry.setup

# if script_options[:start_redis]
#   RedisScripts.instance.with_redis do
#     FixDBForRanges.new.run
#   end
# else
#   RedisScripts.instance.confirm_redis_is_available
#   FixDBForRanges.new.run
# end
# end
