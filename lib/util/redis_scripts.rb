require 'timeout'

module Cisqua
  class RedisScripts
    include Singleton

    def with_redis(conf_path)
      start_redis(conf_path)
      begin
        yield
      ensure
        stop_redis
      end
    end

    def start_redis(conf_path)
      raise 'asked to start redis without shutting it down' unless @redis_thread.nil?

      shutdown!
      @redis_thread = Thread.new do
        system("redis-server #{conf_path}")
      end

      Timeout.timeout(10) do
        loop do
          return if running?

          sleep(0.25)
        end
      end
    rescue Timeout::Error
      raise 'could not start redis'
    end

    def start_easy
      start_redis(Cisqua::Registry.instance.options.redis.conf_path)
    end

    def stop_redis
      shutdown!
      @redis_thread&.join
      @redis_thread = nil
    end

    def running?
      response = `redis-cli ping 2>&1`.strip # Capture the output including stderr
      response == 'PONG'
    end

    def shutdown!
      shutdown
      assert(!running?, 'could not shutdown redis')
    end

    def shutdown
      `redis-cli shutdown 2>/dev/null`
    end
  end
end
