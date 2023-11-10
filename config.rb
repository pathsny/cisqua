module Cisqua
  class Config
    include Singleton
    include SemanticLogger::Loggable

    def startup(registry)
      logger.info('starting redis')
      RedisScripts.instance.start_redis(registry.options.redis.conf_path)
      logger.info('starting batch processor')
      BatchProcessor.instance.start
      @started = true
    end

    def shutdown
      return unless @started

      logger.info('shutdown requested', error_info: $ERROR_INFO, caller:)
      RedisScripts.instance.shutdown!
      BatchProcessor.instance.stop
      @started = false
    end
  end
end
