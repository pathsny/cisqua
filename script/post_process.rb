# Main entry point for rename script. Checks with anidb, adds to mylist etc
require File.expand_path('../lib/libs', __dir__)
require 'optparse'

module Cisqua
  script_options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: post_process'
    opts.on('-oOPTIONS', '--options=OPTIONS', 'location of options config') do |o|
      script_options[:options_file] = o
    end
    opts.on('-t', '--test', 'run for testing') do
      script_options[:test_mode] = true
    end
    opts.on('--dry-run', 'Dry Run. Does not move any files, create any directories or create symlinks') do
      script_options[:dry_run_mode] = true
    end
    opts.on('--debug', 'Overrides log level in options and sets it to debug') do
      script_options[:log_level] = :debug
    end
    opts.on('--logfile=PATH', 'does not log to default log files and instead logs to provided path') do |path|
      script_options[:logfile] = path
    end
  end.parse!

  if script_options[:test_mode]
    TestUtil.prep(
      options_file: script_options[:options_file],
      dry_run: script_options[:dry_run_mode],
      log_level: script_options[:log_level],
      log_file_path: script_options[:logfile],
    )
  else
    Registry.options_file_override = script_options[:options_file]
    options = Registry.load_options
    if script_options.key?(:log_level)
      options[:log_level] = script_options[:log_level]
      AppLogger.log_level = script_options[:log_level]
    end
    AppLogger.log_file = script_options[:logfile] if script_options.key?(:logfile)
    options[:renamer][:dry_run_mode] = script_options[:dry_run_mode] if script_options.key?(:dry_run_mode)
    Registry.options_override = options
  end
  registry = Registry.instance
  RedisScripts.instance.with_redis(registry.options.redis.conf_path) do
    PostProcessor.run(registry.options, registry.scanner, registry.api_client, registry.renamer)
  end
end
