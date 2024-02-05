require 'json'
require 'json/add/time'
require 'active_support'
require 'active_support/core_ext/numeric/time'
require 'action_view'

module Cisqua
  reloadable_const_define :EpisodeIdentifierPattern do
    /^(?<before_prefix>.*?)(?<prefix_word>\b\w+\b)(?:.*?\D)?(?<number>\d+)(?<rest>.*)$/
  end

  class ViewData
    include ActionView::Helpers::DateHelper
    include SemanticLogger::Loggable

    attr_reader :range_formatter

    def initialize(range_formatter)
      @range_formatter = range_formatter
    end

    def updates(queried_at, batch_check, batch_datas)
      {
        last_update: for_batch_check(queried_at, batch_check),
        **for_batch_datas(batch_datas),
      }
    end

    def for_batch_datas(batch_datas)
      batch_datas.each_with_object({ aids: [], scans: [] }) do |bd, data|
        data[:aids] << bd.affected_anime_ids
        data[:scans] << for_batch_data(bd)
      end => {aids:, scans: }
      {
        library: aids.flatten.uniq.map { |aid| for_anime(Anime.find(aid)) },
        scans:,
      }
    end

    def for_anime(anime)
      eps_by_group = range_formatter.from_mylist(anime)
      {
        name: anime.romaji_name,
        combined_name: combined_name_for_anime(anime),
        ended: anime.ended?,
        complete: anime.movie? ? true : MyList.complete?(anime.id),
        air_date: anime.air_date.strftime('%Y-%m-%d'),
        end_date: anime.ended? ? anime.end_date.strftime('%Y-%m-%d') : nil,
        eps_by_group:,
        has_image: anime.metadata&.has_image?,
        **anime.attributes.slice(
          :id,
          :english_name,
          :year,
          :type,
          :episode_count,
          :highest_episode_number,
          :special_ep_count,
        ),
      }
    rescue StandardError, SolidAssert::AssertionFailedError => e
      logger.error('error generating view data', { anime: anime.id, exception: e })
      raise
    end

    private

    def for_batch_check(queried_at, batch_check)
      last_update = { checked_timestamp: queried_at.to_i }
      return last_update if batch_check.nil?

      batch_data = batch_check.batch_data
      result = if batch_data.nil?
        'No Files'
      else
        batch_data.complete? ? 'Complete' : 'In Progress'
      end
      {
        **last_update,
        elapsed_time: "#{time_ago_in_words(batch_check.updated_at)} ago",
        updated_date: batch_check.updated_at.strftime('%a, %Y-%m-%d'),
        updated_time: batch_check.updated_at.strftime('%H:%M:%S'),
        updated_timestamp: batch_check.updated_at.to_i,
        reason: batch_check.request_source,
        result:,
        scan_in_progress: batch_data && !batch_data.complete?,
      }
    end

    def for_batch_data(bd)
      updates = bd.affected_anime_ids.map do |aid|
        anime = Anime.find(aid)
        {
          aid:,
          added: range_formatter.from_fids(anime, bd.processed_fids(aid, :success)),
          duplicate: range_formatter.from_fids(anime, bd.processed_fids(aid, :dups)),
          junk: range_formatter.from_fids(anime, bd.processed_fids(aid, :junk)),
          replaced: for_replacements(anime, bd.replaced_fids(aid)),
          previous: range_formatter.from_fids(anime, bd.processed_fids(aid, :existing)),
          final_status: range_formatter.from_fids(anime, bd.final_fids(aid)),
        }
      end
      {
        id: bd.id,
        started_at: "#{time_ago_in_words(bd.created_at)} ago",
        start_date: bd.created_at.strftime('%a, %Y-%m-%d'),
        start_time: bd.created_at.strftime('%H:%M:%S'),
        source: bd.request_source,
        duration: distance_of_time_in_words(bd.created_at, bd.updated_at),
        file_count: bd.count,
        scanned_count: bd.processed,
        unknowns: bd.unknowns,
        complete: bd.complete?,
        updates:,
      }
    end

    def for_replacements(anime, replaced_fids)
      replaced_files = replaced_fids.map do |r|
        {
          **r,
          new: AnimeFile.find(r[:new]),
          old: AnimeFile.find(r[:old]),
        }
      end
      different_eps = replaced_files.select { |r| r[:new].eid != r[:old].eid }
      different_grps = replaced_files.select { |r| r[:new].gid != r[:old].gid }
      assert(different_eps.empty?, "replaced files have different eps #{different_eps}")
      assert(different_grps.empty?, "replaced files have different eps #{different_grps}")

      reason_groups = replaced_files.group_by { |r| r[:reason].to_json }
      reason_groups.map do |_, grp|
        {
          eps: range_formatter.from_files(anime, grp.map { |i| i[:new] }),
          reason: grp.first[:reason],
        }
      end
    end

    def english_name_is_similar?(romaji_name, english_name)
      return true if english_name.empty?

      normalize(romaji_name) == normalize(english_name)
    end

    def normalize(name)
      name = name.downcase
      name = name.gsub(/[^a-z0-9\s]/, '')
      name.strip
    end

    def combined_name_for_anime(anime)
      romaji_name = anime.romaji_name
      english_name = anime.english_name

      english_name_is_similar?(
        romaji_name,
        english_name,
      ) ? romaji_name : "#{romaji_name} (#{english_name})"
    end
  end
end
