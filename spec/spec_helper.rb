require 'mocha/api'
require 'rspec'
require 'faker'
require 'fakefs/spec_helpers'
require 'date'

require_relative '../lib/libs'
require 'rspec/logging_helper'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  include RSpec::LoggingHelper

  config.mock_with :mocha
  config.capture_log_messages
end

def require_from_root(p)
  require_relative File.join('..', p)
end

OPTIONS_BAK = YAML.load_file(File.expand_path('../script/helpers/options.yml.bak', __dir__))
DUMMY_INFO = YAML.load_file(File.expand_path('dummy_info.yml', __dir__))

def write_file(name, content)
  File.open(name, 'w') { |f| f.write(content) }
end

def read_file(name)
  File.open(name) { |f| return f.read }
end

def resolve_symlink(path)
  File.expand_path(File.readlink(path), File.dirname(path))
end

def create_source_file(path)
  content = FakeFS.without do
    Faker::Lorem.sentence
  end
  write_file(path, content)
  { path:, content: }
end

RSpec::Matchers.define :be_symlink_to do |expected|
  match do |actual|
    File.symlink?(actual) &&
      resolve_symlink(actual) == expected
  end

  failure_message do |actual|
    break "#{actual} is expected to be a symlink" unless File.symlink?(actual)

    "symlink #{actual} was expected to resolve to #{expected} actually resolved to #{resolve_symlink(actual)}"
  end
end

RSpec::Matchers.define :be_moved do
  match do |actual|
    File.symlink?(actual[:path]) ||
      !File.exist?(actual[:path]) ||
      actual[:content] != read_file(actual[:path])
  end

  match_when_negated do |actual|
    !File.symlink?(actual[:path]) &&
      File.exist?(actual[:path]) &&
      actual[:content] == read_file(actual[:path])
  end
end

RSpec::Matchers.define :be_moved_to_without_source_symlink do |expected|
  match do |actual|
    File.exist?(expected) &&
      actual[:content] == read_file(expected) &&
      (!File.symlink?(actual[:path]) || resolve_symlink(actual[:path]) != expected)
  end

  match_when_negated do |_actual|
    raise 'use .to_not be_moved instead'
  end

  failure_message do |actual|
    break "#{expected} should exist" unless File.exist?(expected)
    break "#{actual[:path]} is a symlink to #{expected} which was not expected" \
      unless !File.symlink?(actual[:path]) || resolve_symlink(actual[:path]) != expected

    actual_content = read_file(expected)
    err_msg = "#{expected} was not moved correctly. " +
              "expected content #{actual[:content]} but was #{actual_content}"
    break err_msg unless actual[:content] == actual_content
  end
end

RSpec::Matchers.define :be_moved_to_with_source_symlink do |expected|
  match do |actual|
    File.symlink?(actual[:path]) &&
      resolve_symlink(actual[:path]) == expected &&
      File.exist?(expected) &&
      actual[:content] == read_file(expected)
  end

  match_when_negated do |_actual|
    raise 'use .to_not be_moved instead'
  end

  failure_message do |actual|
    break "#{actual[:path]} should become symlink" unless File.symlink?(actual[:path])

    unless File.exist?(actual[:path]) &&
           resolve_symlink(actual[:path]) == expected
      break "#{actual[:path]} should point to #{expected} \
        but was #{File.readlink(actual[:path])}"
    end
    break "#{expected} should exist" unless File.exist?(expected)

    actual_content = read_file(expected)
    err_msg = "#{expected} was not moved correctly. " +
              "expected content #{actual[:content]} but was #{actual_content}"
    break err_msg unless actual[:content] == actual_content
  end
end
