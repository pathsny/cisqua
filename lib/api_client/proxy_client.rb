require File.join(Cisqua::ROOT_FOLDER, 'net/ranidb')

module Cisqua
  class ProxyClient
    extend Reloadable
    include SemanticLogger::Loggable

    reloadable_const_define :EXPECTED_CALLS_NO_CACHE, %i[connect disconnect].freeze
    reloadable_const_define :EXPECTED_CALLS_TEST_CACHE, %i[
      search_file
      file
      anime
      episode
      mylist_add
      mylist_del_by_fid
    ].freeze

    def initialize(client, test_mode)
      @client = client
      @cache_dir_path = File.absolute_path(
        'udp_anime_info_cache',
        DATA_FOLDER,
      )
      @test_mode = test_mode
    end

    def method_missing(method, *)
      if EXPECTED_CALLS_NO_CACHE.include?(method)
        call_client(method, *)
        return
      end
      assert(
        EXPECTED_CALLS_TEST_CACHE.include?(method),
        "unsupported api call #{method}",
      )

      if @test_mode
        check_cache(method, *) do |*args|
          call_client(method, *args)
        end
      else
        call_client(method, *)
      end
    end

    def check_cache(method, *args)
      raise 'there should be a way to get the data when not in the cache' unless block_given?

      cache_dir = File.join(@cache_dir_path, method.to_s)
      _param_types, param_names = @client.method(method).parameters.transpose

      cache_key = args.zip(param_names)
        .map { |value, name| "#{name}_#{value}" }.join('__')

      file_path = File.join(cache_dir, "#{cache_key}.yml")
      if File.exist?(file_path)
        YAML.load_file(file_path)
      else
        yield(*args).tap do |result|
          FileUtils.mkdir_p(cache_dir)
          File.write(file_path, result.to_yaml)
        end
      end
    end

    def disconnect
      @client.disconnect if @client.connected?
    end

    def call_client(method, *)
      maintain_rate_limit
      @client.connect unless @client.connected
      @client.__send__(method, *)
    end

    private

    def respond_to_missing?(method, *)
      @client.respond_to?(method) || super
    end

    def maintain_rate_limit
      diff = Time.now - @now if @now
      sleep 3 - diff if diff && diff < 3
      @now = Time.now
    end
  end
end
