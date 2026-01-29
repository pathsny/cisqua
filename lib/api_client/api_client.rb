require 'redis'
require 'fileutils'
require 'yaml'
module Cisqua
  require File.join(ROOT_FOLDER, 'net/ranidb')

  class APIClient
    include SemanticLogger::Loggable

    class SynchronizedClient
      def initialize(client)
        @client = client
        @mutex = Mutex.new
      end

      def synchronize
        @mutex.synchronize do
          yield @client
        end
      end
    end

    # Since the scraper can be re-created, we use a setter rather than an initializer
    attr_writer :metadata_scraper

    def initialize(client, redis, options)
      @client = SynchronizedClient.new(client)
      @redis = redis
      @options = options
    end

    def process(_name, ed2k, size)
      search = AnimeFileSearch.find_by_ed2k_and_size(ed2k, size)
      AnimeFileSearch.db_provider.write do |transaction|
        was_found = check_data_or_api_call(AnimeFileSearch, search) do
          response = @client.synchronize { |c| c.search_file(ed2k, size) }
          logger.debug(
            'identified file',
            response:,
          )
          search = AnimeFileSearch.from_api_response(
            transaction:,
            api_response: response&.slice(:fid) || {},
            ed2k:,
            size: size.to_s,
          )
          return nil unless search.known?

          file = AnimeFile.from_api_response(
            transaction:,
            api_response: response[:file],
            id: response[:fid].to_s,
          )
          retrieve_other_details(transaction, file)
          Group.from_api_response(
            transaction:,
            api_response: {
              name: response[:anime][:group_name],
              short_name: response[:anime][:group_short_name],
            },
            id: file.gid,
          )
          AnimeFileMisc.from_api_response(
            transaction:,
            api_response: response[:anime],
            id: file.id,
          )
        end
        if was_found
          return nil unless search.known?

          retrieve_other_details(transaction, search.file)
        end
      end
      @metadata_scraper.ensure_metadata(search.file.aid) if @options.fetch_metadata
      search.file
    rescue StandardError => e
      logger.error('error processing file', e)
      raise
    end

    def retrieve_other_details(transaction, file)
      retrieve_show_details(transaction, file.aid)
      file.eids.each do |eid|
        retrieve_episode_details(transaction, eid)
      end
    end

    def record_status(record)
      return :missing if record.nil?

      record.expired? ? :expired : :ok
    end

    # checks if the record is ok and returns a boolean value.
    # if the record is not ok, it will call the block (which presumably updates the record)
    def check_data_or_api_call(record_type, record)
      status = record_status(record)
      logger.debug('searching local database', {
        name: record_type.name,
        status:,
        key: record&.redis_key,
      })
      return true if status == :ok

      yield
      false
    end

    def disconnect
      @client.synchronize { |c| c.disconnect }
    end

    def add_to_mylist(file)
      if MyList.instance.exist?(file.id)
        logger.debug('already in mylist')
        return
      end

      lid = @client.synchronize { |c| c.mylist_add(file.id) }
      MyList.instance.add_file(file.id)
      logger.debug('Added to my list as ', lid)
      lid
    end

    def remove_from_mylist(fid)
      unless MyList.instance.exist?(fid)
        logger.debug('already not in mylist')
        return
      end

      @client.synchronize { |c| c.mylist_del_by_fid(fid) }.tap do |resp|
        logger.debug('Removed from my list', fid:, resp:)
      end
      MyList.instance.remove_file(fid)
    end

    private

    def retrieve_show_details(transaction, aid)
      anime = Anime.find_by_id(aid)
      check_data_or_api_call(Anime, anime) do
        response = @client.synchronize { |c| c.anime(aid) }
        logger.debug(
          'fetched show',
          response,
        )
        Anime.from_api_response(
          transaction:,
          api_response: response[:anime],
          id: aid,
        )
      end
    end

    def retrieve_episode_details(transaction, eid)
      episode = Episode.find_by_id(eid)
      check_data_or_api_call(Episode, episode) do
        response = @client.synchronize { |c| c.episode(eid) }
        logger.debug(
          'fetched episode',
          response,
        )
        Episode.from_api_response(
          transaction:,
          api_response: response[:episode],
          id: eid,
        )
      end
    end
  end
end
