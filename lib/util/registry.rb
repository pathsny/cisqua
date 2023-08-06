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
    ) do
      def initialize(options_file_param, options_override, test_mode_param)
        self.options_file = options_file_param
        self.test_mode = test_mode_param
        self.options = options_override || Options.load_options(options_file)

        logger = SemanticLogger[Net::AniDBUDP]
        logger.instance_eval("def proto(v = '') ; self.debug v ; end", __FILE__, __LINE__)
        self.anidb_client = Net::AniDBUDP.new(
          *(%i[host port localport user pass nat].map { |k| options.api_client[:anidb][k] }),
          logger,
        )
        self.proxy_client = ProxyClient.new(anidb_client, test_mode)
        self.api_client = APIClient.new(proxy_client)
        self.renamer = Renamer::Renamer.new(options[:renamer])
        self.scanner = FileScanner.new(options[:scanner])
      end

      def self.instance
        @instance ||= new(
          @options_file_override || File.join(DATA_FOLDER, 'options.yml'),
          @options_override || nil,
          @test_mode_override || false,
        )
      end

      def self.options_file_override=(options_file)
        @options_file_override = options_file
      end

      def self.options_override=(options)
        @options_override = options
      end

      def self.test_mode_override=(test_mode)
        @test_mode_override = test_mode
      end

      def self.clear
        @instance = nil
      end
    end
  end
end
