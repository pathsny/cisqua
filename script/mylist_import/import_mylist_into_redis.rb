require File.expand_path('../../lib/libs', __dir__)
require File.join(Cisqua::ROOT_FOLDER, 'net/masks')
require 'optparse'
require 'nokogiri'

module Cisqua
  reloadable_const_define :ED2K_REGEX, %r{^ed2k://\|file\|.*?\|(?<size>\d+)\|(?<ed2k>[a-fA-F0-9]+)\|}

  script_options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: post_process'
    opts.on('-d', '--db=DB', 'which db to import into') do |db|
      script_options[:db] = db
    end
    opts.on('--debug', 'Overrides log level in options and sets it to debug') do
      script_options[:log_level] = :debug
    end
    opts.on('--mylist=PATH', 'where to get the mylist data from') do |path|
      script_options[:mylist] = path
    end
  end.parse!

  raise 'must provide db in redis' unless script_options.key?(:db)

  raise 'must provide path to mylist' unless script_options.key?(:mylist)

  AppLogger.log_file = File.join(DATA_FOLDER, 'log', 'importer.log')
  options = Registry.load_options
  options.redis.db = script_options[:db]
  Registry.options_override = options
  Registry.test_mode_override = true
  options[:log_level] = script_options[:log_level] if script_options.key?(:log_level)
  AppLogger.log_level = options[:log_level]

  RedisScripts.instance.with_redis(options.redis.conf_path) do
    Registry.instance.redis.flushdb
    MylistImporter.new(script_options[:mylist], Registry.instance.proxy_client).run
  end
end
