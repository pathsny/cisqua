require_relative('test_util')

class TestInterface
  def initialize(should_run_fast_mode)
    @should_run_fast_mode = should_run_fast_mode
  end

  attr_reader :should_run_fast_mode

  def self.create(test_config, should_run_fast_mode)
    case test_config[:mode]
    when :cli
      cli(should_run_fast_mode)
    when :web
      web(should_run_fast_mode)
    when :prep
      test_config[:value] == 1 ? TestDummyInterface.new(should_run_fast_mode) : cli(should_run_fast_mode)
    end
  end

  def self.web(should_run_fast_mode)
    require_relative 'test_web_interface'
    TestWebInterface.new(should_run_fast_mode)
  end

  def self.cli(should_run_fast_mode)
    require_relative 'test_cli_interface'
    TestCLIInterface.new(should_run_fast_mode)
  end
end

class TestDummyInterface < TestInterface
  def prep
    Cisqua::TestUtil.prep_for_integration_test(log_level: :debug)
  end

  def start; end

  def stop; end

  def run; end
end
