require 'active_model'
require 'active_support/core_ext/numeric/time'

module Cisqua
  class Torrent
    include Model::AutoIdKey
    include SemanticLogger::Loggable

    key_prefix :tr

    string_attrs :download_dir, :error_string, :hash_string, :name
    time_attrs :added_date, :activity_date, :done_date, :removed_from_client_at
    int_attrs :file_count, :error, :eta, :rate_download, :rate_upload, :size_when_done, :status, :total_size
    float_attrs :percent_done
    bool_attrs :listed

    immutably_belongs_to :torrent_root
    immutably_belongs_to :torrent_hash, foreign_key: :hash_string, scope: :all
    has_many :torrent_files, short_name: :files, redis_key_part: :tfs

    on_save :modify_indices

    def status_name
      case status
      when 0
        :stopped
      when 1
        :queue_verification
      when 2
        :verifying
      when 3
        :queue_download
      when 4
        :downloading
      when 5
        :queue_seeding
      when 6
        :seeding
      else
        raise "Unknown status #{status} for #{name}"
      end
    end

    def error?
      error != 0
    end

    def mark_removed_from_client(transaction: nil)
      db_provider.write(transaction:) do |t|
        update(removed_from_client_at: Time.now, transaction: t)
      end
    end

    # Creates or updates torrents.
    # Return nil if the torrent will be unchanged.
    def self.upsert_from_api_response_if_changed(data, transaction: nil)
      torrent = find_by_hash_string(data.hashString) || new(hash_string: data.hashString)
      torrent.assign_attributes(
        download_dir: data.downloadDir,
        error_string: data.errorString,
        name: data.name,
        added_date: Time.at(data.addedDate),
        activity_date: Time.at(data.activityDate),
        done_date: data.doneDate.zero? ? nil : Time.at(data.doneDate),
        file_count: data.files.count,
        error: data.error,
        eta: data.eta,
        percent_done: data.percentDone.to_f,
        rate_download: data.rateDownload,
        rate_upload: data.rateUpload,
        size_when_done: data.sizeWhenDone,
        status: data.status,
        total_size: data.totalSize,
        removed_from_client_at: nil,
      )
      torrent_files = data.files.map.with_index do |file_data, index|
        TorrentFile.upsert_from_api_response_if_changed(
          torrent_hash_string: data.hashString,
          file_data:,
          file_stat_data: data.file_stats[index],
          transaction:,
        )
      end
      files_have_changed = torrent_files.compact.any?(&:changed?)

      return nil unless torrent.changed? || files_have_changed

      db_provider.write(transaction:) do |t|
        torrent.update(transaction: t)
      end
    end

    def self.updated_since(start_time)
      db_provider.bypass_cache do |redis|
        redis.zrevrangebyscore('tr:timestamps', '+inf', start_time.to_i + 1).map do |hash_string|
          find(hash_string)
        end
      end
    end

    def self.listed_torrents
      db_provider.bypass_cache do |redis|
        redis.zrange('tr:listed_torrents', 0, -1)
      end.map { |hash_string| find(hash_string) }
    end

    def modify_indices(operation, transaction)
      case operation
      when :create, :update
        update_indices(transaction)
      when :delete
        delete_indices(transaction)
      else
        raise "Unknown operation #{operation}"
      end
    end

    def update_indices(transaction)
      db_provider.write(transaction:) do |t|
        if updated_at_changed?
          t.add_operation do |pipeline|
            pipeline.zadd('tr:timestamps', updated_at.to_i, hash_string)
          end
        end

        if listed_changed?
          t.add_operation do |pipeline|
            if listed
              pipeline.sadd('tr:listed', hash_string)
            else
              pipeline.srem('tr:listed', hash_string)
            end
          end
        end
      end
    end

    def delete_indices(transaction)
      db_provider.write(transaction:) do |t|
        t.add_operation do |pipeline|
          pipeline.zrem('tr:timestamps', hash_string)
          pipeline.srem('tr:listed', hash_string)
        end
      end
    end
  end
end
