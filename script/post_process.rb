# Main entry point for rename script. Checks with anidb, adds to mylist etc
require File.expand_path('../lib/libs', __dir__)
require File.expand_path('helpers/load_options', __dir__)
require 'optparse'

Thread.abort_on_exception = true

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
options = ScriptOptions.load_options(script_options[:options_file])
options[:log_level] = script_options[:log_level] if script_options.key?(:log_level)
options[:renamer][:dry_run_mode] = script_options[:dry_run_mode] if script_options.key?(:dry_run_mode)

Loggers.log_level = (options[:log_level])
if script_options.key?(:logfile) || script_options[:test_mode]
  logfile_path = script_options[:logfile] || File.expand_path('../data/test_data/anidb.log', __dir__)
  Loggers.setup_log_file(logfile_path)
end
PostProcessor.run(script_options[:test_mode] || false, options)
