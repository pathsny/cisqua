require_relative '../lib/libs'
require 'rspec'
require 'rspec/logging_helper'
require_relative('../spec_util/matchers')

# Runs faster, but maybe inaccurate. Useful for development
# We dont clear the file data between runs, so only the final
# result can be asserted.
FAST_INTEGRATION_SPEC = ENV['FAST_MODE'] || false

RSpec.configure do |_config|
  logfile_path = File.expand_path('../data/test_data/log/anidb.log', __dir__)
  AppLogger.log_file = logfile_path
end
