module Cisqua
  reloadable_const_define :Registry do
    Struct.new(
      :options_file,
      :test_mode,
      :options,
      :anidb_client,
      :proxy_client,
      :api_client,
      :redis,
      :renamer,
      :scanner,
      :file_processor,
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

        self.redis = Redis.new(db: options.redis.db)
        self.proxy_client = ProxyClient.new(anidb_client, test_mode)
        self.api_client = APIClient.new(proxy_client, redis)
        self.renamer = Renamer::Renamer.new(options[:renamer])
        self.scanner = FileScanner.new(options[:scanner])
        FileProcessor.instance.set_dependencies(scanner, api_client, renamer)
        BatchProcessor.instance.options = options
        BatchProcessor.instance.scanner = scanner
        Model::Redisable.redis = redis
      end

      def self.instance
        @instance ||= new(
          @options_override || load_options,
          @test_mode_override || false,
        )
      end

      def self.load_options
        Options.load_options(
          @options_file_override || File.join(DATA_FOLDER, 'options.yml'),
        )
      end

      class << self
        attr_accessor :options_file_override, :options_override, :test_mode_override
      end

      def self.clear
        @instance = nil
      end
    end
  end
end
