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

    def updates(queried_at, batch_check, batch_datas)
      {
        last_update: for_batch_check(queried_at, batch_check),
        **for_batch_datas(batch_datas),
      }
    end

    def for_batch_datas(batch_datas)
      scans = batch_datas.map { |bd| for_batch_data(bd) }
      a_ids = scans.flat_map { |scan| scan[:updates].map { |u| u[:aid] } }.uniq
      {
        scans:,
        library: a_ids.map { |aid| for_anime(Anime.find(aid)) },
      }
    end

    def for_anime(anime)
      range = Range.find_by_id(anime.id)
      {
        id: anime.id,
        name: anime.romaji_name,
        combined_name: combined_name_for_anime(anime),
        english_name: anime.english_name,
        ended: anime.ended?,
        complete: anime.movie? ? true : MyList.complete?(anime.id),
        year: anime.year,
        air_date: anime.air_date.strftime('%Y-%m-%d'),
        end_date: anime.ended? ? anime.end_date.strftime('%Y-%m-%d') : nil,
        type: anime.type,
        has_image: anime.metadata&.has_image?,
        eps: range.simple,
        eps_w_grps: range.with_groups,
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
      updates = (bd.updates || {}).map do |aid, update|
        anime = Anime.find(aid)
        {
          aid: anime.id,
          **update.transform_values do |range|
            {
              eps: range['simple'],
              eps_w_grps: range['with_groups'],
            }
          end,
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
        scanned_count: bd.unknowns.count +
          bd.success_fids.count +
          bd.duplicate_fids.count +
          bd.replacement_fids.count,
        unknowns: bd.unknowns,
        complete: bd.complete?,
        updates:,
      }
    end

    def english_name_is_similar?(romaji_name, english_name)
      return true if english_name.empty?

      normalize(romaji_name) == normalize(english_name)
    end

    def normalize(name)
      # Convert to lowercase
      name = name.downcase

      # Remove non-alphanumeric characters except numbers
      name = name.gsub(/[^a-z0-9\s]/, '')

      # Trim spaces
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
