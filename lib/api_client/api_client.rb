require 'redis'
require 'fileutils'
require 'yaml'
module Cisqua
  require File.join(ROOT_FOLDER, 'net/ranidb')

  class APIClient
    include SemanticLogger::Loggable

    def initialize(client, redis)
      @client = client
      @redis = redis
    end

    def process(_name, ed2k, size)
      search = AnimeFileSearch.find_by_ed2k_and_size(ed2k, size)
      was_found = check_data_or_api_call(AnimeFileSearch, search) do
        response = @client.search_file(ed2k, size)
        logger.debug(
          'identified file',
          response,
        )
        search = AnimeFileSearch.from_api_response(
          response&.slice(:fid) || {},
          ed2k:,
          size:,
        ).save
        return nil unless search.known?

        file = AnimeFile.from_api_response(
          response[:file],
          id: response[:fid],
        ).save
        retrieve_other_details(search.file)
        Group.from_api_response({
          name: response[:anime][:group_name],
          short_name: response[:anime][:group_short_name],
        },
          id: file.gid).save
        AnimeFileMisc.from_api_response(
          response[:anime],
          id: file.id,
        ).save
      end
      if was_found
        return nil unless search.known?

        retrieve_other_details(search.file)
      end

      add_to_mylist(search.fid)
      munge_into_expected_format(search.fid)
    end

    def retrieve_other_details(file)
      retrieve_show_details(file.aid)
      file.eids.each do |eid|
        retrieve_episode_details(eid)
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
        key: record&.make_key_for_instance,
      })
      return true if status == :ok

      yield
      false
    end

    def munge_into_expected_format(fid)
      file = AnimeFile.find(fid)
      misc_m = AnimeFileMisc.find(fid)
      anime = Anime.find(file.aid)
      misc = {
        highest_episode_number: misc_m.highest_episode_number,
        year: misc_m.year,
        type: misc_m.type,
        romaji_name: misc_m.romaji_name,
        english_name: misc_m.english_name,
        epno: misc_m.epno,
        ep_english_name: misc_m.ep_english_name,
        ep_romaji_name: misc_m.ep_romaji_name,
        group_name: misc_m.group_name,
        group_short_name: misc_m.group_short_name,
      }.merge(
        dateflags: anime.dateflags,
        year: anime.year,
        type: anime.type,
        romaji_name: anime.romaji_name,
        english_name: anime.english_name,
        episodes: anime.episode_count,
        highest_episode_number: anime.highest_episode_number,
        air_date: anime.air_date.to_i.to_s,
        end_date: anime.end_date.to_i.to_s,
        is_18_restricted: anime.is_18_restricted ? '1' : '0',
        ended: anime.ended?,
      )
      {
        file: {
          aid: file.aid,
          eid: file.eid,
          gid: file.gid,
          state: file.state,
          quality: file.quality,
          source: file.source,
          video_resolution: file.video_resolution,
          dub_language: file.dub_language,
          sub_language: file.sub_language,
          length: file.length,
          crc_status: file.crc_status,
          censored: file.censored,
          version: file.version,
        },
        anime: misc,
        fid:,
      }
    end

    def disconnect
      @client.disconnect
    end

    def add_to_mylist(fid)
      if MyList.exist?(fid)
        logger.debug('already in mylist')
        return
      end

      lid = @client.mylist_add(fid)
      MyList.add_file(fid)
      logger.debug('Added to my list as ', lid)
      lid
    end

    def remove_from_mylist(fid)
      unless MyList.exist?(fid)
        logger.debug('already not in mylist')
        return
      end

      @client.mylist_del_by_fid(fid).tap do |resp|
        logger.debug('Removed from my list', fid:, resp:)
      end
      MyList.remove_file(fid)
    end

    private

    def retrieve_show_details(aid)
      anime = Anime.find_by_id(aid)
      check_data_or_api_call(Anime, anime) do
        response = @client.anime(aid)
        logger.debug(
          'fetched show',
          response,
        )
        Anime.from_api_response(response[:anime], id: aid).save
      end
    end

    def retrieve_episode_details(eid)
      episode = Episode.find_by_id(eid)
      check_data_or_api_call(Episode, episode) do
        response = @client.episode(eid)
        logger.debug(
          'fetched episode',
          response,
        )
        Episode.from_api_response(response[:episode], id: eid).save
      end
    end
  end
end
