require 'nokogiri'

# known Issues
# special_ep_count is wrong sometimes
#
module Cisqua
  class AnimeXMLImporter
    include SemanticLogger::Loggable

    attr_reader :doc, :aid, :path, :updated_at

    Cisqua.reloadable_const_define :GROUPS_TO_IGNORE, %w[
      269
      1441
    ].freeze

    def initialize(aid, path, client, updated_at)
      @aid = aid
      @path = path
      @doc = Nokogiri::XML(File.open(path))
      @client = client
      @updated_at = updated_at
    end

    def make_anime
      series_info_node = doc.at_xpath('/anime/seriesInfo')
      episode_count_node = doc.at_xpath('/anime/episodes/episodeCount')
      airing_date_node = series_info_node.at_xpath('airingDate')
      name_node = series_info_node.at_xpath('name')
      end_date_str = airing_date_node['end']
      year_str = airing_date_node['year']
      unless year_str.include?('-')
        year_str = "#{year_str}-#{year_str}"
      end

      if end_date_str == '?'
        end_date = Time.at(0)
        dateflags = '0'
      else
        end_date = parse_time(airing_date_node['end'])
        dateflags = '16'
      end
      anime_data = {
        id: doc.at_xpath('/anime')['id'],
        episode_count: episode_count_node.at_xpath('normal/@totalEpisodes').value.to_i,
        highest_episode_number: episode_count_node.at_xpath('normal/@totalEpisodes').value.to_i,
        special_ep_count: episode_count_node.at_xpath('special/@totalEpisodes').value.to_i,

        is_18_restricted: !series_info_node.at_xpath('genres/genre[@id="80"]').nil?,

        air_date: parse_time(airing_date_node['start']),
        end_date:,
        dateflags:,
        year: year_str,
        type: series_info_node.at_xpath('type').text.strip,
        romaji_name: name_node.at_xpath('romanji').text.strip.gsub('`', "'"),
        english_name: name_node.at_xpath('english').text.strip.gsub('`', "'"),
        updated_at:,
        data_source: 'mylist-import',
      }
      Anime.new(anime_data).save_unique
    end

    def to_hash
      { aid: @aid, path: @path }
    end

    def parse_time_2digit_yr(str)
      parts = Date._strptime(str, '%d.%m.%y')
      Time.utc(parts[:year], parts[:mon], parts[:mday])
    end

    def parse_time(str)
      str.in_time_zone('UTC').to_time
    end

    def make_episode(anime, episode_node)
      aired_string = episode_node.at_xpath('airingDate').text.strip
      aired = aired_string.empty? ? Time.at(0) : parse_time_2digit_yr(aired_string)

      episode_data = {
        id: episode_node['id'],
        aired:,
        aid: anime.id,
        length: episode_node['length'],
        epno: episode_node['number'].rjust(2, '0'),
        english_name: episode_node.at_xpath('name/english').text.strip.gsub('`', "'"),
        romaji_name: episode_node.at_xpath('name/romanji').text.strip.gsub('`', "'"),
        kanji_name: episode_node.at_xpath('name/kanji').text.strip,
        updated_at:,
        data_source: 'mylist-import',
      }
      Episode.new(episode_data).save_unique
    end

    def make_files(anime, episode_node)
      episode = Episode.find(episode_node['id'])
      files_node = episode_node.at_xpath('files')
      ep_relations = files_node.xpath('file_ep_relations/file')

      file_nodes = files_node.xpath('file')
      file_nodes.each do |file_node|
        # when a file covers multiple episodes, its listed once under each episode.
        # The file_ep relations node under each episode will list the file by id and
        # every episode except the first episode.

        # so if we see a file_ep_relations node for this file that does include this episode
        # we have probably seen it before, so we will not process this file.
        already_created_file = ep_relations.any? do |ep_relation_node|
          ep_relation_node['id'] == file_node['id'] &&
            ep_relation_node['episode'] == episode_node['id']
        end
        next if already_created_file

        ed2k_link = file_node.at_xpath('hashInformation/ed2kLink').text
        match = ed2k_link.match(ED2K_REGEX)
        search_data = {
          fid: file_node['id'],
          ed2k: match[:ed2k],
          size: match[:size].to_i,
          updated_at:,
          data_source: 'mylist-import',
        }
        AnimeFileSearch.new(search_data).save_unique

        version_match = /\Av(?<digit>\d)\z/.match(file_node['version'])
        version = version_match[:digit].to_i

        quality_node = file_node.at_xpath('quality')
        audio_langs = quality_node.xpath('audioStreams/audio').filter_map do |node|
          node['language'] unless node['language'].empty?
        end
        sub_langs = quality_node.xpath('subtitleStreams/subtitles').filter_map do |node|
          node['language'] unless node['language'].empty?
        end

        state = file_node['state']
        states = Net::FILE_STATE_MASKS.select { |_state_type, m| state.to_i & m != 0 }
        crc_status = %i[crc_ok crc_err].find(proc { :crc_unchecked }) { |state_key| states.key?(state_key) }
        censored = %i[uncensored censored].find(proc { :unknown }) { |state_key| states.key?(state_key) }

        other_episodes = ep_relations.filter_map do |ep_rel|
          next nil if ep_rel['id'] != file_node['id']

          start_pct = Integer(ep_rel['start'])
          end_pct = Integer(ep_rel['end'])
          ep_pct = end_pct - start_pct
          assert(ep_pct.positive?, "error calculating other episodes #{ep_rel}")
          "#{ep_rel['episode']},#{ep_pct}"
        end

        released_by_node = file_node.at_xpath('releasedBy')

        file_data = {
          id: file_node['id'],
          length: '', # placeholder,
          version:,
          aid: anime.id,
          eid: episode.id,
          gid: released_by_node['id'],
          state: file_node['state'],
          quality: quality_node['name'],
          source: quality_node['source'],
          video_resolution: quality_node.at_xpath('video')['resolution'],
          dub_language: audio_langs.empty? ? 'none' : audio_langs.join('\''),
          sub_language: sub_langs.empty? ? 'none' : sub_langs.join('\''),
          other_episodes: other_episodes.join('\''),
          crc_status:,
          censored:,
          updated_at:,
          data_source: 'mylist-import',
        }
        file = AnimeFile.new(file_data).save_unique
        MyList.add_file(file.id)

        if file.gid == '0'
          group_name = 'raw/unknown'
          group_short_name = 'raw'
        else
          group_name = released_by_node.at_xpath('name').text.strip
          group_short_name = released_by_node.at_xpath('shortName').text.strip
        end

        if Group.find_by_id(file.gid).nil?
          Group.new(
            id: file.gid,
            name: group_name,
            short_name: group_short_name,
            updated_at:,
            data_source: 'mylist-import',
          ).save_unique
        end

        misc_data = {
          id: file_node['id'],
          highest_episode_number: anime.highest_episode_number,
          year: anime.year,
          type: anime.type,
          romaji_name: anime.romaji_name,
          english_name: anime.english_name,
          epno: file.epno,
          ep_english_name: episode.english_name,
          ep_romaji_name: episode.romaji_name,
          group_name:,
          group_short_name:,
          updated_at:,
          data_source: 'mylist-import',
        }

        begin
          AnimeFileMisc.new(misc_data).save_unique
        rescue SolidAssert::AssertionFailedError, StandardError => e
          data = { misc: misc_data, file: file_data }
          raise ImportError.new('error adding misc', data:, inner_error: e)
        end
      rescue SolidAssert::AssertionFailedError, StandardError => e
        raise ImportError.new('error adding file', data: { fid: file_node['id'] }, inner_error: e)
      end
      episode
    rescue SolidAssert::AssertionFailedError, StandardError => e
      raise ImportError.new('error adding episode', data: { eid: episode_node['id'] }, inner_error: e)
    end

    def import_anime
      anime = make_anime
      episode_nodes = doc.xpath('/anime/episodes/episode')
      episode_nodes.each do |episode_node|
        make_episode(anime, episode_node)
      end
      anime
    rescue StandardError => e
      raise ImportError.new('error importing anime', data: { aid: @aid }, inner_error: e)
    end

    def import_files
      doc.xpath('/anime/episodes/groups/group').each do |group_node|
        next if GROUPS_TO_IGNORE.include?(group_node['id'])

        gid = group_node['id']
        next unless Group.find_by_id(gid).nil?

        Group.new({
          id: gid,
          name: group_node.at_xpath('name').text.strip,
          short_name: group_node.at_xpath('shortName').text.strip,
          updated_at:,
          data_source: 'mylist-import',
        }).save_unique
      end
      episode_nodes = doc.xpath('/anime/episodes/episode')
      anime = Anime.find(@aid)
      episode_nodes.each do |episode_node|
        make_files(anime, episode_node)
      end
    rescue SolidAssert::AssertionFailedError, StandardError => e
      raise ImportError.new('error importing anime', data: { aid: @aid }, inner_error: e)
    end

    def run_and_display_errors
      run
    rescue ImportError => e
      logger.error("Error importing anime: #{{ msg: e.message, data: e.data, inner: e.inner_error }}")
      raise
    end
  end
end
