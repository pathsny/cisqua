require File.expand_path('lib/libs', __dir__)
require_relative('config')
require 'optparse'
require 'English'

STARTUP_OPTIONS = Cisqua::Config.instance.startup

require 'sinatra/base'
require 'sinatra/custom_logger'
require 'rack/contrib'

module Cisqua
  class App < Sinatra::Base
    helpers Sinatra::CustomLogger
    include SemanticLogger::Loggable

    set :logger, SemanticLogger['Sinatra']

    use Rack::CommonLogger, Cisqua::AppLogger.rack_logger
    use Rack::Static, urls: ['/show_images'], root: DATA_FOLDER
    use Rack::JSONBodyParser

    set :connections, []
    set :events_queue, Queue.new
    set :bind, '0.0.0.0'
    set :view_data, Registry.instance.view_data
    set :test_mode_default_value, Registry.instance.test_mode
    set :protection, except: :frame_options
    set :show_exceptions, false

    logger.info("Starting Cisqua client in #{Registry.instance.test_mode ? 'TEST MODE' : 'REGULAR MODE'}")
    logger.info("the sinatra environment is #{settings.environment}")

    attr_reader :connections

    before do
      @view_data = settings.view_data
      @connections = []
    end

    def self.on_batch_update(**event_data)
      logger.debug('received an event to stream', event_data[:event])
      return if settings.connections.empty?

      events_queue << event_data
    end

    def self.on_torrent_sync(torrents)
      events_queue << { event: :torrent_sync, torrents: }
    end

    on_start do
      Thread.new do
        if STARTUP_OPTIONS.start_repl
          EmbeddedConsole.instance.start('web', sinatra_settings: settings)
          Cisqua::App.quit!
        end
      end
    end

    configure do
      BatchProcessor.instance.on_update(&method(:on_batch_update))
      TorrentRoot.on_update(&method(:on_torrent_sync))

      Thread.new do
        loop do
          item = events_queue.pop
          data = case item[:event]
          when :check
            view_data.update_for_check
          when :process
            view_data.update_for_batch_progress(item[:batch_data])
          when :complete
            view_data.update_for_batch_complete(item[:batch_data])
          when :torrent_sync
            view_data.update_for_torrents(item[:torrents])
          end
          settings.connections.each { |conn| stream_data(conn, data) }
        end
      end

      Thread.new do
        loop do
          sleep 29
          settings.connections.each { |conn| conn << ": keepalive\n\n" }
        end
      end
    end

    configure :development do
      set :static_cache_control, %i[public nocache]

      Cisqua::AppLogger.log_level = :debug
    end

    configure :production do
      set :static_cache_control, [:public, :must_revalidate, { max_age: 60 }]
      Cisqua::AppLogger.log_level = :info
    end

    get '/' do
      initial_data = @view_data.initial_data
      erb :index, locals: {
        initial_data:,
        test_mode: settings.test_mode_default_value,
        dry_run: Registry.instance.options[:renamer][:dry_run_mode],
      }
    end

    post '/start_scan' do
      Cisqua::AppLogger.log_level = params[:debug_mode] ? :debug : :info
      Registry.instance.options[:renamer][:dry_run_mode] = params[:dry_run]

      result = BatchProcessor.instance.enqueue_request('From Web')
      logger.debug("Start Scan Status: #{result[:status]}")

      content_type :json
      {
        scan_enque_result: result[:status],
        updates: @view_data.updates_for_request_scan,
      }.to_json
    rescue StandardError => e
      logger.error('Error starting scan:', e)
      raise
    end

    def self.stream_data(conn, data)
      queried_at = data.dig(:last_update, :connection, :queried_at)
      assert(queried_at, 'Must always return queried_at')
      conn << "id: #{queried_at}\n"
      conn << "data: #{data.to_json}\n\n"
    end

    def choose_start_timestamp(request, params)
      last_event_id = request.env['HTTP_LAST_EVENT_ID'].to_i
      query_timestamp = params[:queried_timestamp].to_i
      [last_event_id, query_timestamp].max
    end

    get '/refresh', provides: 'text/event-stream' do
      stream :keep_open do |out|
        settings.connections << out

        start_time = Time.at(choose_start_timestamp(request, params))
        data = @view_data.updates_after(start_time:)
        self.class.stream_data(out, data)
        out.callback do
          settings.connections.delete(out)
        end
      end
    end

    get '/library' do
      cursor = params[:cursor]
      limit = params[:limit].to_i || 10
      search = params[:search]

      content_type :json

      result = search ?
        MyList.instance.animes_search_sorted(search, cursor, limit) :
        MyList.instance.animes_sorted(cursor, limit)
      library_data = result[:animes].map { |anime| @view_data.for_anime(anime) }

      {
        library_data:,
        next_cursor: result[:next_cursor],
        count: result[:count],
      }.to_json
    end

    get '/favicon.ico' do
      content_type 'image/x-icon'
      favicon_type = settings.environment == :production ? 'production' : 'development'
      logger.debug("using favicon.#{favicon_type}.ico")
      send_file(
        File.join(ROOT_FOLDER, 'public', "favicon.#{favicon_type}.ico"),
        disposition: :inline,
      )
    end

    get '/anime/:id' do
      content_type :json
      aid = params[:id]
      anime = Anime.find_by_id(aid)
      if anime.nil?
        logger.error('Anime not found', { anime_id: aid })
        status 404
        next { error: 'Anime not found' }.to_json
      end
      @view_data.for_anime_id(aid).to_json
    end

    get '/scans/count' do
      content_type :json
      BatchCheck.instance.latest(:all).count.to_json
    end

    get '/scans/:id' do
      content_type :json
      batch_data = BatchData.find_by_id(params[:id])
      if batch_data.nil?
        logger.error('BatchData not found', { batch_id: params[:id] })
        status 404
        next { error: 'BatchData not found' }.to_json
      end
      @view_data.for_batch_data(batch_data).to_json
    end

    get '/version' do
      content_type :json
      AppVersion.fetch.to_json
    end

    post '/test/hack_udp_cache' do
      unless Registry.instance.test_mode
        logger.error('Forbidden access to hack_udp_cache in non-test mode')
        status 403
        next { error: 'Forbidden in non-test mode' }.to_json
      end

      require File.join(ROOT_FOLDER, 'integration_spec', 'test_util')
      data = JSON.parse(request.body.read)
      TestUtil.hack_udp_cache(data)

      content_type :json
      { status: 'success' }.to_json
    end

    post '/test/transmission_stub' do
      unless Registry.instance.test_mode
        logger.error('Forbidden access to transmission_stub in non-test mode')
        status 403
        next { error: 'Forbidden in non-test mode' }.to_json
      end

      stub_file = params['stub_file']
      unless stub_file
        logger.error('Missing stub_file parameter in transmission_stub request', { data: })
        status 400
        next { error: 'Missing stub_file parameter' }.to_json
      end

      require File.join(ROOT_FOLDER, 'integration_spec', 'transmission_stub')
      TransmissionStub.instance.use_file(stub_file)

      content_type :json
      { status: 'success' }.to_json
    end

    get '/health_check' do
      status 200
      content_type :json
      { status: 'ok' }.to_json
    end

    error do
      e = env['sinatra.error']
      logger.error('Error during web request', { status_code: response.status }, e)
      raise e
    end
  end
end

Cisqua::App.run!
