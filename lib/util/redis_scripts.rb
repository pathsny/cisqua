require 'timeout'
require 'open3'

module Cisqua
  class RedisScripts
    include Singleton

    def with_redis
      start_redis
      begin
        yield
      ensure
        stop_redis
      end
    end

    def start_redis
      raise 'asked to start redis without shutting it down' unless @redis_thread.nil?

      shutdown!
      redis_dev_conf_path = File.expand_path(File.join(__dir__, '..', '..', 'data', 'redis.conf'))
      cmd_path = File.expand_path(File.join(__dir__, '..', '..', 'script', 'redis-stack-server'))
      cmd = "#{cmd_path} #{redis_dev_conf_path}"
      @redis_thread = Thread.new do
        puts "running #{cmd}"

        Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
          stdin.close

          stdout_thread = Thread.new do
            stdout.each_line do |line|
              SemanticLogger['Redis'].debug(line.strip)
            end
          end

          stderr_thread = Thread.new do
            stderr.each_line do |line|
              SemanticLogger['Redis'].warn(line.strip)
            end
          end

          stdout_thread.join
          stderr_thread.join

          wait_thr.value
        end
      end
      confirm_redis_is_available
    end

    def ensure_redis
      return if running?

      start_redis
    end

    def confirm_redis_is_available
      Timeout.timeout(20) do
        loop do
          return if running?

          sleep(0.25)
        end
      end
    rescue Timeout::Error
      raise 'could not start redis'
    end

    def stop_redis
      shutdown!
      @redis_thread&.join
      @redis_thread = nil
    end

    def running?
      output = Redis.new(host: redis_host, port: redis_port).ping
      output == 'PONG'
    rescue StandardError
      false
    end

    def shutdown!
      shutdown
      assert(!running?, 'could not shutdown redis')
    end

    def shutdown
      `redis-cli shutdown 2>/dev/null`
    end

    def redis_host
      ENV['REDIS_HOST'] || 'localhost'
    end

    def redis_port
      ENV['REDIS_PORT'] || 6379
    end
  end
end
