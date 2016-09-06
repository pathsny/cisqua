# Main entry point for rename script. Checks with anidb, adds to mylist etc
require File.expand_path('../../lib/libs', __FILE__)

Thread.abort_on_exception = true

PostProcessor.run(ARGV[0] == 'test_client')