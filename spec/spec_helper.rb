require_relative '../lib/libs'
require 'mocha/api'
require 'rspec'
require 'faker'
require 'fakefs/spec_helpers'
require 'date'

require 'rspec/logging_helper'
require_relative('../spec_util/matchers')

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  include RSpec::LoggingHelper

  config.mock_with :mocha
  config.capture_log_messages
end

def require_from_root(path)
  require_relative File.join('..', path)
end

OPTIONS_BAK = YAML.load_file(File.expand_path('../script/helpers/options.yml.bak', __dir__))
DUMMY_INFO = YAML.load_file(File.expand_path('dummy_info.yml', __dir__))

def write_file(name, content)
  File.write(name, content)
end

def create_source_file(path)
  content = FakeFS.without do
    Faker::Lorem.sentence
  end
  write_file(path, content)
  { path:, content: }
end
