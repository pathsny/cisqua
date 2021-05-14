# Main entry point for rename script. Checks with anidb, adds to mylist etc
require File.expand_path('../../lib/libs', __FILE__)
require File.expand_path('helpers/load_options', __dir__)
require 'optparse'

Thread.abort_on_exception = true
test_mode = false

script_options = {}
options_file = nil
OptionParser.new do |opts|
  opts.banner = "Usage: post_process"
  opts.on("-oOPTIONS", "--options=OPTIONS", "location of options config") do |o|
    options_file = o
  end
  opts.on("-t", "--test", "run for testing") do
    test_mode = true
  end
  opts.on("--debug", "Overrides log level in options and sets it to debug") do
    script_options[:log_level] = :debug
  end
end.parse!
options = ScriptOptions.load_options(options_file)
options[:log_level] = script_options[:log_level] if script_options.has_key?(:log_level)

Loggers.set_log_level_from_option(options[:log_level])
PostProcessor.run(test_mode, options)
