require 'faraday'

module Cisqua
  class TvdbScraper
    include SemanticLogger::Loggable

    def initialize(options, override: false)
      @options = options
      @override = override
    end

    def fetch_images(meta)
      image_url = fetch_image_url(meta)
      return nil if image_url.nil?

      main, _dot, ext = image_url.rpartition('.')
      thumb_url = "#{main}_t.#{ext}"
      [image_url, thumb_url]
    end

    def fetch_image_url(meta)
      logger.info('about to fetch tvdb for', meta.instance_values)
      response = fetch_show_data(meta)
      return nil unless response.success?

      season_num_for_image_data = meta.source_data['defaulttvdbseason']
      season_num_for_image = if season_num_for_image_data&.match(/^\d+$/) && season_num_for_image_data.to_i != 1
        season_num_for_image_data.to_i
      end
      response_data = response.body['data']
      if season_num_for_image
        seasons = response_data['seasons'].select do |season|
          season['seriesId'] == response_data['id'] &&
            season['number'] == season_num_for_image &&
            !season['image'].nil?
        end
        return seasons.first['image'] unless seasons.empty?
      end
      response_data['image']
    end

    def fetch_show_data(meta)
      show_id = meta.source_id
      assert(show_id.match(/^\d+$/), 'must be digit')
      fetch_show_data_by_id(show_id)
    end

    def fetch_show_data_by_id(show_id)
      assert(show_id.match(/^\d+$/), 'must be digit')

      token = MetadataTokens.token(:tvdb)
      response = fetch_show_data_impl(show_id, token)

      return response unless response.status == 401

      token = refresh_token
      fetch_show_data_impl(show_id, token)
    end

    def fetch_show_data_impl(show_id, token)
      conn = Faraday.new(
        url: 'https://api4.thetvdb.com',
      ) do |f|
        f.headers = {
          'Authorization' => "Bearer #{token}",
        }
        f.response :json
      end
      conn.get("/v4/series/#{show_id}/extended", meta: 'translations', short: true)
    end

    def refresh_token
      conn = Faraday.new(
        url: 'https://api4.thetvdb.com',
      ) do |f|
        f.request :json
        f.response :json
      end
      response = conn.post('v4/login', { apikey: @options.tvdb_api_key })
      return nil unless response.success?

      response.body.dig('data', 'token').tap do |token|
        MetadataTokens.update_instance(tvdb_token: token)
      end
    end
  end
end
