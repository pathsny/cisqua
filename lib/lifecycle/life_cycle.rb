module Cisqua
  class LifeCycle
    include SemanticLogger::Loggable
    include Singleton

    def setup_registry(test_mode: false)
      if test_mode
        require File.join(ROOT_FOLDER, 'integration_spec', 'test_util')
        log_file_path = File.join(ROOT_FOLDER, 'data/test_data/log/anidb.log')
        TestUtil.prep_registry(log_file_path:, log_level: :debug)
      end

      Registry.setup
    end

    # @mode [:start, :ensure, :confirm]
    # start - Starts redis. Will first shutdown if running.
    # ensure - Ensures redis is running. Will start if not running.
    # confirm - Confirms redis is running. Will raise an error if not running.
    def setup_redis(mode:)
      logger.debug('setup redis in mode', mode:)

      case mode
      when :start
        logger.info('starting Redis')
        RedisScripts.instance.start_redis
      when :ensure
        logger.info('ensuring Redis is running')
        RedisScripts.instance.ensure_redis
      when :confirm
        logger.info('confirming Redis is running')
        RedisScripts.instance.confirm_redis_is_available
      end
    end

    def run_migrations
      DbMigrations.instance.run
    end

    def start_processors
      logger.info('starting batch processor')
      BatchProcessor.instance.start
      # logger.info('starting torrent processor')
      # TorrentProcessor.instance.start
    end

    def stop_processors
      TorrentProcessor.instance.stop
      BatchProcessor.instance.stop
    end
  end
end
