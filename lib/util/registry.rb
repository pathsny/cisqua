require_relative '../../web/view_data'

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

        self.redis = Redis.new(db: options.redis.db)
        self.proxy_client = ProxyClient.new(anidb_client, test_mode)
        self.api_client = APIClient.new(proxy_client, redis, options.api_client)
        self.renamer = Renamer::Renamer.new(options[:renamer], api_client)
        self.scanner = FileScanner.new(options[:scanner])
        FileProcessor.instance.set_dependencies(scanner, api_client, renamer)
        BatchProcessor.instance.options = options
        BatchProcessor.instance.scanner = scanner
        self.range_formatter = RangeFormatter.new
        self.view_data = ViewData.new(range_formatter)
        Model::Redisable.redis = redis
        make_metadata_scraper
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
