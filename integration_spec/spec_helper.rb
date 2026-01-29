require_relative '../lib/libs'
require 'rspec'
require 'rspec/logging_helper'
require_relative('../spec_util/matchers')
require_relative('test_data_provider')
require_relative('test_util')
require('jsondiff')

def test_config
  @test_config ||= begin
    mode = ENV.fetch('MODE', :regular).to_sym
    interface = ENV.fetch('TEST_INTERFACE', 'web').to_sym
    assert(%i[web cli].include?(interface), "unknown interface for test #{interface}")
    assert([
      :regular, # full set of scans and assertions
      :prep, # runs the scanner and just the prep for the specified iteration
      :fast, # ensures that scans are done, but does not clear files, reset etc
    ].include?(mode), "unknown test mode #{mode}")
    value = nil
    if mode == :prep
      v = ENV.fetch('PREP_VALUE', 'all')
      value = v == 'all' ? :all : Integer(v)
    end

    { mode:, value:, interface: }
  end
end

def test_interface
  @test_interface ||= case test_config[:interface]
  when :cli
    require_relative 'test_cli_interface'
    TestCLIInterface.new
  when :web
    require_relative 'test_web_interface'
    TestWebInterface.new
  end
end

RSpec.configure do |config|
  log_file_path = File.expand_path('../data/test_data/log/anidb.log', __dir__)
  Cisqua::AppLogger.setup_logging(test_mode: true)
  Cisqua::AppLogger.log_file = log_file_path
  Cisqua::AppLogger.disable_stdout_logging

  config.before(:context) do
    puts 'Setting up test environment...'
    if test_config[:mode] == :fast
      redis_start_mode = :ensure
    else
      redis_start_mode = :start
      Cisqua::TestUtil.prep_redis
    end

    Cisqua::LifeCycle.instance.setup_redis(mode: redis_start_mode)
    Cisqua::LifeCycle.instance.setup_registry(test_mode: true)
    Cisqua::LifeCycle.instance.run_migrations
  end

  config.after(:context) do
    Cisqua::Registry.clear
    Cisqua::RedisScripts.instance.stop_redis unless test_config[:mode] == :fast
  end
end

RSpec::Matchers.define :be_equivalent_json_to do |expected_data, name|
  match do |actual_data|
    diff = JsonDiff.generate(expected_data, actual_data)
    diff.empty?.tap do |result|
      Cisqua::TestDataProvider.instance.clear_bad_data(name) if result
      Cisqua::TestDataProvider.instance.save_bad_data(name, actual_data) unless result
    end
  end

  failure_message do |actual_data|
    diff = JsonDiff.generate(expected_data, actual_data)
    "Expected json data as in #{name}. However, data is transformed as follows\n
    #{diff}"
  end
end
