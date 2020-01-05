# Main entry point for rename script. Checks with anidb, adds to mylist etc
require File.expand_path('../../lib/libs', __FILE__)
require File.expand_path('helpers/load_options', __dir__)
require 'optparse'

Thread.abort_on_exception = true
test_mode = false
options_file = nil

options_file = nil
OptionParser.new do |opts|
  opts.banner = "Usage: console -n anidb"
  opts.on("-oOPTIONS", "--options=OPTIONS", "location of options config") do |o|
    options_file = o
  end
  opts.on("-t", "--test", "run for testing") do
    test_mode = true
  end
end.parse!
options = ScriptOptions.load_options(options_file)
PostProcessor.run(test_mode, options)
