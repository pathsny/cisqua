require_relative '../lib/libs'
require 'active_support'
require 'active_support/all'
require 'active_support/testing/time_helpers'
require 'mocha/api'
require 'rspec'
require 'faker'
require 'fakefs/spec_helpers'
require 'date'

require 'rspec/logging_helper'
require_relative('../spec_util/matchers')

RSpec.shared_context 'with semantic_logger helper' do
  let(:logger) { SemanticLogger::Test::CaptureLogEvents.new }
end

RSpec.configure do |config|
  config.include Cisqua

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    config.include ActiveSupport::Testing::TimeHelpers
  end

  config.include_context 'with semantic_logger helper'

  config.before do
    SemanticLogger::Logger.stubs(:processor).returns(logger)
  end

  config.mock_with :mocha
end

def require_from_root(path)
  require_relative File.join('..', path)
end

OPTIONS_BAK = YAML.load_file(File.expand_path('../script/helpers/options.yml.bak', __dir__))
DUMMY_INFO = YAML.load_file(File.expand_path('dummy_info.yml', __dir__))

def dummy_work_item(path)
  file = Cisqua::WorkItemFile.new(name: File.basename(path), path:)
  Cisqua::WorkItem.new(file:, info: DUMMY_INFO, request_type: :standard)
end

def unknown_work_item(path)
  file = Cisqua::WorkItemFile.new(name: File.basename(path), path:)
  Cisqua::WorkItem.new(file:, request_type: :standard)
end

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
