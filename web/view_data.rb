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
    include ActionView::Helpers::NumberHelper
    include SemanticLogger::Loggable

    attr_reader :range_formatter

    def initialize(range_formatter)
      @range_formatter = range_formatter
    end

    def initial_data
      bc = BatchCheck.instance
      tr = TorrentRoot.instance
      make_update({
        last_update: {
          **for_batch_check(bc),
          **for_torrent_sync(tr),
        },
        **for_batch_datas(bc.latest(50)),
        **for_torrents(TorrentRoot.instance.torrents),
      })
    end

    def updates_after(start_time:)
      make_update({
        last_update: {
          **for_batch_check_after(BatchCheck.instance, start_time:),
          **for_torrent_sync_after(TorrentRoot.instance, start_time:),
        },
        **for_batch_datas(BatchData.updated_since(start_time)),
        **for_torrents_after(start_time:),
      })
    end

    def updates_for_request_scan
      make_update({})
    end

    def update_for_check
      make_update({
        last_update: {
          **for_batch_check(BatchCheck.instance),
        },
      })
    end

    def update_for_batch_progress(batch_data)
      make_update({
        **for_batch_datas([batch_data]),
      })
    end

    def update_for_batch_complete(batch_data)
      make_update({
        last_update: {
          **for_batch_check(BatchCheck.instance),
        },
        **for_batch_datas([batch_data]),
      })
    end

    def update_for_torrents(torrents)
      make_update({
        last_update: {
          **for_torrent_sync(TorrentRoot.instance),
        },
        **for_torrents(torrents),
      })
    end

    def make_update(content)
      {
        **content.except(:last_update),
        last_update: {
          connection: {
            queried_at: Time.now.to_i,
          },
          **(content[:last_update] || {}),
        },
      }
    end

    def for_batch_datas(batch_datas)
      batch_datas.each_with_object({ aids: [], scans: [] }) do |bd, data|
        data[:aids] << bd.sorted_anime_ids
        data[:scans] << for_batch_data(bd)
      end => {aids:, scans: }
      {
        library: aids.flatten.uniq.map { |aid| for_anime_id(aid) },
        scans:,
      }
    end

    def for_anime_id(aid)
      for_anime(Anime.find(aid))
    end

    def for_anime(anime)
      eps_by_group = range_formatter.from_mylist(anime)
      {
        name: anime.romaji_name,
        combined_name: combined_name_for_anime(anime),
        ended: anime.ended?,
        complete: anime.movie? ? true : MyList.instance.entries[anime.id].complete?,
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
      logger.error('error generating view data', { anime: anime&.id, exception: e })
      raise
    end

    def for_batch_data(bd)
      updates = bd.sorted_anime_ids.reverse.map do |aid|
        anime = Anime.find(aid)
        {
          aid:,
          added: range_formatter.from_fids(anime, bd.processed_fids(aid, :success)),
          duplicate: range_formatter.from_fids(anime, bd.processed_fids(aid, :dup)),
          junk: range_formatter.from_fids(anime, bd.processed_fids(aid, :junk)),
          replaced: for_replacements(anime, bd.replaced_fids(aid)),
          previous: range_formatter.from_fids(anime, bd.snapshots.get(aid).fids.to_a),
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
        sources: bd.raw_files.map { |raw_file| for_raw_file(raw_file) },
        scanned_count: bd.processed,
        unknowns: bd.raw_files.filter_map { |f| f.name if f.result == :unknown },
        complete: bd.complete?,
        updates:,
      }
    end

    def for_torrents(torrents)
      {
        torrents: torrents
          .sort_by(&:added_date)
          .reverse
          .map { |torrent| for_torrent(torrent) },
      }
    end

    def for_torrents_after(start_time:)
      {
        torrents: Torrent.updated_since(start_time).sort_by(&:added_date)
          .reverse
          .map { |torrent| for_torrent(torrent) },
      }
    end

    def for_torrent_sync(torrent_root)
      {
        torrents: {
          **torrent_root.slice(:sync_error_name, :sync_error_msg),
          synced_at: torrent_root.synced_at.to_i,
          is_stale: torrent_root.is_stale?,
        },
      }
    end

    def for_torrent_sync_after(torrent_root, start_time:)
      if torrent_root.nil? || torrent_root.updated_at < start_time
        {}
      else
        for_torrent_sync(torrent_root)
      end
    end

    def for_torrent(torrent)
      {
        **torrent.attributes.slice(
          :hash_string,
          :name,
          :error_string,
          :rate_download,
          :rate_upload,
          :size_when_done,
          :status,
          :status_name,
          :total_size,
        ),
        added_at: torrent.added_date.to_i,
        added_date: torrent.added_date.strftime('%b %d, %Y'),
        activity_date: torrent.activity_date.strftime('%b %d, %Y'),
        done_date: torrent.done_date&.strftime('%b %d, %Y'),
        has_error: torrent.error?,
        error_string: torrent.error_string,
        eta: torrent.eta,
        percent_done: (torrent.percent_done * 100).round(2),
        files: torrent.files.map { |file| for_torrent_file(file) },
      }
    end

    def for_torrent_file(torrent_file)
      {
        **torrent_file.attributes.slice(:name, :length, :bytes_completed, :priority, :wanted),
        completed: torrent_file.completed?,
      }
    end

    private

    def base_last_update(queried_at)
      {
        connection: {
          queried_at:,
        },
      }
    end

    def for_batch_check_after(batch_check, start_time:)
      if batch_check.nil? || batch_check.updated_at < start_time
        {}
      else
        for_batch_check(batch_check)
      end
    end

    def for_batch_check(batch_check)
      return nil if batch_check.nil?

      batch_data = batch_check.latest(1).first
      result = if batch_data.nil?
        'No Files'
      else
        batch_data.complete? ? 'Complete' : 'In Progress'
      end
      {
        scans: {
          checked_at: batch_check.updated_at.to_i,
          reason: batch_check.request_source,
          scanned_at: batch_data&.created_at&.to_i,
          result:,
          scan_in_progress: batch_data && !batch_data.complete?,
        },
      }
    end

    def number_to_human_speed(bytes_per_second)
      "#{number_to_human_size(bytes_per_second)}/s"
    end

    def for_raw_file(raw_file)
      result = case raw_file.result
      when nil
        nil
      when :success
        :added
      when :dup
        :duplicate
      else
        raw_file.result
      end
      file_data = raw_file.attributes.slice(:name, :result).compact.merge(result:)
      return file_data if result.nil? || result == :unknown

      file_data.merge(
        aid: raw_file.file.aid,
        ep_name: Renamer::NameGenerator.generate_name(raw_file.file),
      )
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
