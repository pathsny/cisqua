require 'transmission'

module Cisqua
  class TorrentProcessor
    include Singleton
    include SemanticLogger::Loggable

    attr_accessor :options

    def initialize
      @input = Queue.new
    end

    def start
      assert(@started.nil?, 'cannot start more than once')
      assert(!options.nil?, 'cannot start unless dependencies are set')

      @started = true

      sync_thread = Thread.new do
        Thread.current.name = 'torrent_sync_queue'
        loop do
          @input << :sync
          sleep options.poll_interval_sec
        end
      end

      @worker_thread = Thread.new do
        Thread.current.name = 'torrent_processor'
        loop do
          item = @input.pop
          case item
          when :sync
            sync_torrents
          when :end
            break
          end
        end
        sync_thread.exit
      end
      @worker_thread.abort_on_exception = true
    end

    def sync_torrents
      sync_torrents_impl
    rescue StandardError => e
      logger.error('error during torrent sync', exception: e)
      TorrentRoot.instance.sync_error(e)
    end

    def sync_torrents_impl
      relevant = torrent_api_data.select do |torrent|
        torrent.downloadDir == options.watch_dir
      end
      TorrentRoot.instance.sync(relevant)
    end

    def stop
      @input << :end
    end

    def fetch_data_for_torrent(torrent)
      hash_string = torrent.hash_string
      Transmission::Model::Torrent.find(hash_string, connector: rpc)
    end

    def torrent_api_data
      Transmission::Model::Torrent.all(
        connector: rpc,
      ).torrents
    end

    def rpc
      @rpc ||= Transmission::RPC.new(
        host: options.host,
        port: options.port,
        ssl: false,
        credentials: {
          username: options.user,
          password: options.pass,
        },
      )
    end
  end
end
