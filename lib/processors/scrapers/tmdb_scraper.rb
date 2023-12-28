require 'faraday'

module Cisqua
  class TmdbScraper
    include SemanticLogger::Loggable
    def initialize(options, override: false)
      @options = options
      @override = override
      @image_config_data = nil
    end

    def fetch_images(meta)
      fetch_images_impl do |conn|
        response = fetch_show_data(conn, meta.source_id)
        response.body
      end
    end

    def fetch_images_impl
      conn = fetch_authed_conn
      config = image_config(conn)
      show_data = yield(conn)
      poster_path = show_data&.[]('poster_path')
      return nil if poster_path.nil?

      [
        File.join(config['base_url'], 'original', poster_path),
        File.join(config['base_url'], 'w342', poster_path),
      ]
    end

    def fetch_images_by_imdb_id(imdb_id)
      fetch_images_impl do |conn|
        response = fetch_show_data_by_imdb_id(conn, imdb_id)
        response.body.dig('movie_results', 0)
      end
    end

    def fetch_show_data_by_imdb_id(conn, imdb_id)
      conn.get("3/find/#{imdb_id}", { external_source: 'imdb_id' })
    end

    def make_conn(token)
      Faraday.new(
        url: 'https://api.themoviedb.org',
      ) do |f|
        f.headers = {
          'Authorization' => "Bearer #{token}",
        }
        f.response :json
      end
    end

    def fetch_show_data(conn, show_id)
      conn.get("3/movie/#{show_id}")
    end

    def fetch_authed_conn
      token = MetadataTokens.token(:tmdb)
      conn = make_conn(token)
      response = conn.get('/3/authentication')
      assert(response.success?, 'must succeed')
      conn
    end

    def image_config(conn)
      if !@image_config_data || @image_config_data[:fetched_at] + 48.hours > Time.now
        response = conn.get('3/configuration')
        @image_config_data = {
          fetched_at: Time.now,
          data: response.body['images'],
        }
      end
      @image_config_data[:data]
    end
  end
end
