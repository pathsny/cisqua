class TestCLIInterface < TestInterface
  def prep
    Cisqua::TestUtil.prep_for_integration_test(log_level: :debug)
  end

  def start
    Cisqua::RedisScripts.instance.start_redis(Cisqua::Registry.instance.options.redis.conf_path) unless should_run_fast_mode
    @processor = Cisqua::PostProcessor.new(
      Cisqua::Registry.instance.options,
      Cisqua::Registry.instance.scanner,
      Cisqua::FileProcessor.instance,
    )
    @processor.start
  end

  def stop
    @processor.stop
    Cisqua::RedisScripts.instance.stop_redis unless should_run_fast_mode
  end

  def run
    @processor.run
  end
end
