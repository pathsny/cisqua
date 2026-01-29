require_relative '../../web/view_data'
require 'connection_pool'

module Cisqua
  reloadable_const_define :Registry do
    Struct.new(
      :anidb_client,
      :api_client,
      :file_processor,
      :image_scrapers,
      :metadata_scraper,
      :options,
      :options_file,
      :proxy_client,
      :range_formatter,
      :redis,
      :db_provider,
      :renamer,
      :scanner,
      :test_mode,
      :view_data,
    ) do
      def initialize(options_override, test_mode_param)
        self.options_file = @options_file_override
        self.test_mode = test_mode_param

        self.options = options_override || load_options

        logger = SemanticLogger[Net::AniDBUDP]
        logger.instance_eval("def proto(v = '') ; self.debug v ; end", __FILE__, __LINE__)
        self.anidb_client = Net::AniDBUDP.new(
          *(%i[host port localport user pass nat].map { |k| options.api_client[:anidb][k] }),
          logger,
        )

        build_all_associations!
        self.redis = make_redis
        self.db_provider = Model::Saveable::DbProvider.new(redis)
        self.proxy_client = ProxyClient.new(anidb_client, test_mode)
        self.api_client = APIClient.new(proxy_client, redis, options.api_client)
        self.renamer = Renamer::Renamer.new(options[:renamer], api_client)
        self.scanner = FileScanner.new(options[:scanner])
        FileProcessor.instance.set_dependencies(scanner, api_client, renamer)
        BatchProcessor.instance.options = options
        BatchProcessor.instance.scanner = scanner
        TorrentProcessor.instance.options = options.transmission
        self.range_formatter = RangeFormatter.new
        self.view_data = ViewData.new(range_formatter)
        Model::Redisable.db_provider = db_provider

        make_metadata_scraper(test_mode:)
      end

      def make_redis
        host = RedisScripts.instance.redis_host
        port = RedisScripts.instance.redis_port
        puts "Connecting to Redis at host #{host} on port #{port}"
        ConnectionPool::Wrapper.new(size: 10, timeout: 5) do
          Redis.new(db: 0, host:, port:)
        end
      end

      def make_metadata_scraper(additional_options = {})
        tmdb_scraper = TmdbScraper.new(options[:metadata], **additional_options)
        self.image_scrapers = {
          tvdb: TvdbScraper.new(options[:metadata], **additional_options),
          tmdb: tmdb_scraper,
          imdb: ImdbScraper.new(tmdb_scraper),
        }
        self.metadata_scraper = MetadataScraper.new(
          options[:metadata],
          image_scrapers:,
          **additional_options,
        )
        BatchProcessor.instance.metadata_scraper = metadata_scraper
        api_client.metadata_scraper = metadata_scraper
      end

      def build_all_associations!
        model_registry = Model::Saveable::ModelRegistry.instance
        model_registry.clear
        self.class.__get_model_classes.each { |klass| model_registry.register(klass) }
        model_registry.each_model { |_, klass| klass.build_associations! }
      end

      class << self
        attr_accessor :options_file_override, :options_override, :test_mode_override

        def reload!
          clear
          Dir[File.join(Cisqua::ROOT_FOLDER, 'lib', '**/*')].each do |f|
            load f unless File.directory?(f)
          end
          if const_defined?(:TransmissionStub)
            TransmissionStub.instance.restore_adapter
            load File.join(Cisqua::ROOT_FOLDER, 'integration_spec', 'transmission_stub.rb')
          end
          setup
        end

        def clear
          model_registry = Model::Saveable::ModelRegistry.instance

          model_registry.each_model do |_name, klass|
            klass.clear_associations
          end
          model_registry.clear

          @instance&.db_provider&.clear_cache

          @instance = nil
        end

        def __get_model_classes
          classes = ObjectSpace.each_object(Class)
          classes.select do |klass|
            klass.include?(Model::Saveable)
          rescue StandardError
            false
          end
        end

        def setup
          raise 'cannot setup twice' if @instance

          @instance = new(
            @options_override || load_options,
            @test_mode_override || false,
          )
        end

        def instance
          setup unless @instance
          @instance
        end

        def load_options
          Options.load_options(
            @options_file_override || File.join(DATA_FOLDER, 'options.yml'),
          )
        end
      end

      def pretty_print_instance_variables
        [:options]
      end
    end
  end
end
