require 'faraday'

module Cisqua
  reloadable_const_define :MAPPING_URL, 'https://raw.githubusercontent.com/Anime-Lists/anime-lists/master/anime-list.xml'.freeze
  reloadable_const_define :LOCAL_PATH, 'anime_list.xml'.freeze

  class MetadataScraper
    include SemanticLogger::Loggable
    attr_reader :image_scrapers

    def initialize(options, image_scrapers:, override: false)
      @options = options
      @image_scrapers = image_scrapers
      @override = override
    end

    def ensure_mapping
      logger.debug('ensuring metadata mapping is current')
      return if file_is_current(mapping_path, MAPPING_URL)

      download_mapping
    end

    def ensure_metadata(aid)
      m = ensure_metadata_only(aid)
      if m.nil?
        return false
      end

      fetch_image_from_meta(m)
    end

    def ensure_metadata_only(aid)
      m = Metadata.find_by_id(aid) unless @override
      return m unless m.nil?

      update_metadata(aid)
    end

    def fetch_image(aid)
      m = Metadata.find_by_id(aid)
      fetch_image_from_meta(m)
    end

    def fetch_image_from_meta(meta)
      return false if meta.image_fetch_attempted? && !@override

      image_scraper = @image_scrapers[meta.source]
      unless image_scraper
        logger.warn('no image source for show', aid: meta.id)
        return false
      end

      images = image_scraper.fetch_images(meta)
      if images.nil?
        meta.update(image_status: :missing)
      else
        img_url, thumb_url = images
        save_image(img_url, "a#{meta.id}")
        save_image(thumb_url, "a#{meta.id}_t")
        meta.update(image_status: :fetched)
      end
    end

    def image_fetch_supported(meta)
      @image_scrapers.keys.include?(meta.source)
    end

    def save_image(url, img_name)
      ext = File.extname(url)
      filename = "#{img_name}#{ext}"

      response = Faraday.get(url)
      image_folder = File.join(
        DATA_FOLDER,
        'show_images',
      )
      File.binwrite(
        File.join(image_folder, filename),
        response.body,
      )
    end

    def update_from_overrides(aid, overrides)
      return unless overrides.key?(aid)

      override_value = overrides[aid][:value]
      Metadata.new(
        id: aid,
        updated_at: Time.now,
        **override_value,
      ).save
    end

    def update_metadata(aid)
      logger.debug('setting metadata for', aid:)

      overrides = YAML.load_file(File.join(DATA_FOLDER, 'metadata_overrides.yml'))
      m = update_from_overrides(aid, overrides)
      return m unless m.nil?

      meta = try_tvdb_metadata(aid)
      return meta unless meta.nil?

      tmdb_id = get_tmdb_id(aid)
      if !tmdb_id.nil? && tmdb_id.match(/^\d+$/)
        return Metadata.new(
          id: aid,
          source: :tmdb,
          source_id: tmdb_id,
          updated_at: Time.now,
          source_data: {},
        ).save
      end

      imdb_id = get_imdb_id(aid)
      unless imdb_id.nil? || imdb_id == 'unknown'
        return Metadata.new(
          id: aid,
          source: :imdb,
          source_id: imdb_id,
          updated_at: Time.now,
          source_data: {},
        ).save
      end
      existing = Cisqua::Metadata.find_by_id(aid)
      # delete a record if its already there since we have no meta
      Cisqua::Metadata.clear_record(aid) if existing
      nil
    end

    def get_tmdb_id(aid)
      doc = mapping
      doc.at_xpath("/anime-list/anime[@anidbid=\"#{aid}\"]/@tmdbid").value
    rescue StandardError => _e
      nil
    end

    def try_tvdb_metadata(aid)
      doc = mapping
      tvdb_node = doc.at_xpath("/anime-list/anime[@anidbid=\"#{aid}\" and @tvdbid]")
      tvdb_id = tvdb_node&.[]('tvdbid')
      return nil unless tvdb_id&.match(/^\d+$/)

      tvdb_metadata_node(
        aid:,
        source_id: tvdb_id,
        source_data: { 'defaulttvdbseason' => tvdb_node&.[]('defaulttvdbseason') },
      )
    end

    def tvdb_metadata_node(aid:, source_id:, source_data:)
      Metadata.new(
        id: aid,
        source: :tvdb,
        source_id:,
        updated_at: Time.now,
        source_data:,
      ).save
    end

    def get_imdb_id(aid)
      doc = mapping
      doc.at_xpath("/anime-list/anime[@anidbid=\"#{aid}\"]/@imdbid").value
    rescue StandardError => _e
      nil
    end

    private

    def mapping_path
      File.join(DATA_FOLDER, LOCAL_PATH)
    end

    def mapping
      Nokogiri::XML(File.open(mapping_path))
    end

    def file_is_current(file_path, url)
      return true if file_is_recent(file_path)

      if etag_is_unchanged(url)
        FileUtils.touch(mapping_path)
        true
      else
        false
      end
    end

    def file_is_recent(file_path)
      return false unless File.exist?(file_path)

      age = Time.now - File.mtime(file_path)
      (age < @options[:file_age_threshold]).tap do |dec|
        logger.debug('file recency', recent: dec, age:, threshold: @options[:file_age_threshold])
      end
    end

    def etag_is_unchanged(url)
      remote_headers = Faraday.head(url)&.headers
      if remote_headers.nil?
        logger.warn('no remote headers?')
      end
      return false unless remote_headers

      remote_etag = remote_headers['etag']
      local_etag = MetadataTokens.find_if_exists&.mapping_etag
      (remote_etag == local_etag).tap do |dec|
        logger.debug('etag info', dec:, remote_etag:, local_etag:)
      end
    end

    def download_mapping
      response = Faraday.get(MAPPING_URL)
      if response.success?
        File.write(mapping_path, response.body)
        MetadataTokens.update_instance(mapping_etag: response.headers['etag'])
        logger.debug('successfully updated mapping file')
      else
        logger.error('Error: Failed to download tvdb mapping file', status: response.status)
      end
    end
  end
end
