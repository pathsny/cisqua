require File.expand_path('lib/libs', __dir__)
require_relative('config')
require 'optparse'

begin
  OptionParser.new do |opts|
    opts.on('-t', '--test', 'run for testing') do
      require File.join(Cisqua::ROOT_FOLDER, 'integration_spec', 'test_util')
      Cisqua::TestUtil.prep
    end
  end.parse!

  at_exit do
    Cisqua::Config.instance.shutdown
  end

  Cisqua::Config.instance.startup(Cisqua::Registry.instance)

  require 'sinatra/base'
  require 'sinatra/custom_logger'
rescue StandardError => e
  formatter = Cisqua::ErrorFormatter.new(e)
  abort formatter.formatted
end

module Cisqua
  class App < Sinatra::Base
    helpers Sinatra::CustomLogger
    include SemanticLogger::Loggable

    set :connections, []
    set :bind, '0.0.0.0'
    set :view_data, Registry.instance.view_data
    set :test_mode_default_value, Registry.instance.test_mode
    set :protection, except: :frame_options

    logger.info("Starting Cisqua client in #{Registry.instance.test_mode ? 'TEST MODE' : 'REGULAR MODE'}")
    logger.info("the sinatra environment is #{settings.environment}")

    attr_reader :connections

    before do
      @view_data = settings.view_data
      @connections = []
    end

    configure :development do
      set :static_cache_control, %i[public nocache]
      logger = SemanticLogger['Sinatra']
      logger.level = :debug
      set :logger, logger
      Cisqua::AppLogger.log_level = :debug
      set :logging, Logger::DEBUG
    end

    configure :production do
      set :static_cache_control, [:public, :must_revalidate, { max_age: 60 }]
      logger = SemanticLogger['Sinatra']
      logger.level = :info
      set :logger, logger
      Cisqua::AppLogger.log_level = :info
    end

    get '/' do
      initial_data = @view_data.for_scans(
        Time.now,
        BatchCheck.find_if_exists,
        BatchData.latest(50),
      )
      erb :index, locals: {
        initial_data:,
        test_mode: settings.test_mode_default_value,
        dry_run: Registry.instance.options[:renamer][:dry_run_mode],
      }
    end

    post '/start_scan' do
      Cisqua::AppLogger.log_level = params['debug_mode'] == 'on' ? :debug : :info
      Registry.instance.options[:renamer][:dry_run_mode] = params['dry_run'] == 'on'

      result = BatchProcessor.instance.enqueue_request('Start Scan From Web', method(:on_process))
      logger.debug("Start Scan Status: #{result[:status]}")

      content_type :json
      {
        scan_enque_result: result[:status],
        updates: updates_from(params['queried-timestamp'].to_i),
      }.to_json
    end

    def on_process(state, batch_data)
      logger.info('got called back with ', {
        state:,
        id: batch_data.id,
        progress: batch_data.progress,
        complete: batch_data.complete?,
        conns: settings.connections.count,
      })
      data = @view_data.for_scans(
        Time.now,
        BatchCheck.find_if_exists,
        [batch_data],
      )
      settings.connections.each { |conn| stream_data(conn, data) }
    end

    def stream_data(conn, data)
      conn << "data: #{data.to_json}\n\n"
    end

    def updates_from(queried_timestamp)
      @view_data.for_scans(
        Time.now,
        BatchCheck.find_if_exists,
        BatchData.updated_since(queried_timestamp),
      )
    end

    get '/refresh', provides: 'text/event-stream' do
      stream :keep_open do |out|
        settings.connections << out
        logger.info('the length is now ', { count: settings.connections.count })
        stream_data(out, updates_from(params['queried-timestamp'].to_i))
        out.callback do
          logger.debug('Connnection Closed')
          settings.connections.delete(out)
        end
      end
    end

    get '/favicon.ico' do
      content_type 'image/x-icon'
      logger.debug("using favicon.#{settings.environment}.ico")
      send_file(
        File.join(Cisqua::ROOT_FOLDER, 'public', "favicon.#{settings.environment}.ico"),
        disposition: :inline,
      )
    end
  end
end

Cisqua::App.run!
