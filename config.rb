module Cisqua
  class Config
    include Singleton
    include SemanticLogger::Loggable

    Options = Struct.new(:run_redis_locally, :start_repl, :stub_transmission_file)

    def startup
      logger.info("Starting Cisqua with options: #{ENV.fetch('RACK_ENV', nil)}")
      parse_options

      LifeCycle.instance.setup_registry(test_mode: ENV['RACK_ENV'] == 'test')

      if Registry.instance.test_mode
        require(File.join(
          ROOT_FOLDER,
          'integration_spec',
          'transmission_stub.rb',
        ))
        TransmissionStub.instance.register_middleware

        if @options.stub_transmission_file
          logger.info("Using stub file: #{@options.stub_transmission_file}")
          TransmissionStub.instance.use_file(
            File.join(
              TEST_DATA_FOLDER,
              @options.stub_transmission_file,
            ),
          )
        end
      end

      if @options.start_repl
        AppLogger.disable_stdout_logging
      end

      LifeCycle.instance.setup_redis(
        mode: @options.run_redis_locally ? :start : :confirm,
      )
      LifeCycle.instance.run_migrations
      setup_exit_handlers
      LifeCycle.instance.start_processors
      @started = true

      logger.info('Startup complete', options: @options.to_h)

      @options
    end

    def parse_options
      @options = Options.new
      OptionParser.new do |opts|
        opts.on('-l', '--local-redis', 'run redis locally') do
          @options.run_redis_locally = true
        end
        opts.on('-r', '--repl', 'start REPL') do
          @options.start_repl = true
        end
        opts.on('-s ', '--stub-transmission STUB_FILE', 'stub transmission') do |stub_file|
          @options.stub_transmission_file = stub_file
        end
      end.parse!
      logger.info("Options: #{@options.inspect}")
    rescue StandardError => e
      formatter = Cisqua::ErrorFormatter.new(e)
      abort formatter.formatted
    end

    def setup_exit_handlers
      at_exit do
        if $ERROR_INFO
          logger.error('Exiting due to an exception.', $ERROR_INFO)
        else
          logger.info('Shutting Down.')
        end
        shutdown
      end
    end

    def shutdown
      return unless @started

      RedisScripts.instance.shutdown! if @options.run_redis_locally

      BatchProcessor.instance.stop
      TorrentProcessor.instance.stop
      @started = false
    end
  end
end
