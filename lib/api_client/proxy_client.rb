require File.join(ROOT_FOLDER, 'net/ranidb')

class ProxyClient
  SAFE_METHODS = %i[connect disconnect].freeze
  READ_METHODS = %i[search_file anime episode mylist_by_aid].freeze
  WRITE_METHODS = %i[mylist_add].freeze

  def initialize(options, test_mode)
    @client = make_client(options[:anidb])
    @cache_dir_path = File.absolute_path(
      'udp_anime_info_cache',
      DATA_FOLDER,
    )
    @test_mode = test_mode
  end

  def method_missing(method, *args)
    if SAFE_METHODS.include?(method)
      call_client(method, *args)
      return
    end

    if READ_METHODS.include?(method)
      if @test_mode
        check_cache(method, *args) do
          call_client(method, *args)
        end
      else
        call_client(method, *args)
      end
    else
      assert(WRITE_METHODS.include?(method), "unsupported api method call #{method}")
      call_client(method, *args) unless @test_mode
    end
  end

  def check_cache(method, *args)
    raise 'there should be a way to get the data when not in the cache' unless block_given?

    cache_dir = File.join(@cache_dir_path, method.to_s)
    _param_types, param_names = @client.method(method).parameters.transpose
    cache_key = args.zip(param_names).reduce('') do |key, (value, name)|
      existing = key.empty? ? key : "#{key}__"
      "#{existing}#{name}_#{value}"
    end

    file_path = File.join(cache_dir, "#{cache_key}.yml")
    if File.exist?(file_path)
      YAML.load_file(file_path)
    else
      yield.tap do |result|
        FileUtils.mkdir_p(cache_dir)
        File.write(file_path, result.to_yaml)
      end
    end
  end

  def is_cacheable(method)
    return true if READ_METHODS.include?(method)

    raise "not configured for api call #{method}" unless WRITE_METHODS.include?(method)
  end

  def disconnect
    @client.disconnect if @client.connected?
  end

  private

  def call_client(method, *args)
    maintain_rate_limit
    @client.connect unless @client.connected
    @client.__send__(method, *args)
  end

  def respond_to_missing?(method, *)
    @client.respond_to?(method) || super
  end

  def maintain_rate_limit
    diff = Time.now - @now if @now
    sleep 3 - diff if diff && diff < 3
    @now = Time.now
  end

  def make_client(api_options)
    params = %i[host port localport user pass nat].map { |k| api_options[k] }
    logger = Loggers::UDPClient
    logger.instance_eval("def proto(v = '') ; self.debug v ; end", __FILE__, __LINE__)
    Net::AniDBUDP.new(*params, logger)
  end
end
