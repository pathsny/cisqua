# Root record for Torrents

require 'active_model'

module Cisqua
  class TorrentRoot
    include Model::Saveable
    include SemanticLogger::Loggable

    time_attrs :synced_at
    has_many :torrents, redis_key_part: :tr
    string_attrs :sync_error_msg, :sync_error_name
    @on_update_callbacks = []

    single_instance :trs

    def self.on_update(&block)
      @on_update_callbacks << block
    end

    def self.broadcast(updated_torrents)
      @on_update_callbacks.map { |cb| cb.call(updated_torrents) }
    end

    def self.instance
      if find_if_exists.nil?
        new.update
      end
      find
    end

    def sync(torrents_data, transaction: nil)
      ###
      # 1. Ensure we have a TorrentHash record for every hash ever known.
      # 2. Make sure any listed torrent that is no longer present is unlisted.
      # 3. Make sure every torrent in the data is listed. Formerly listed torrents
      #    will not be listed again. Instead a new torrent will be created.
      # 4. Update every torrent with the latest data from the data array.
      # 5. Broadcast the changes.

      db_provider.write(transaction:) do |t|
        # Create/update TorrentHash records for all torrents
        hashes_and_data = torrents_data.map do |data|
          logger.error('handling', hash_string: data.hashString)
          hash = TorrentHash.upsert(hash_string: data.hashString, transaction: t)
          [hash, data]
        end

        # Get current and transmission hash strings
        current_hash_strings = listed_hashes
        transmission_hash_strings = torrents_data.map(&:hashString)

        # Find hashes that need to be unlisted
        unlisted_hashes = current_hash_strings - transmission_hash_strings

        # Update torrents and track which ones changed
        updated_torrents = []

        # Update or create listed torrents
        hashes_and_data.each do |hash, data|
          updated = Torrent.upsert_from_api_response_if_changed(data, transaction: t)
          updated_torrents << updated if updated
        end

        # Unlist torrents that are no longer present
        unlisted_torrents = unlisted_hashes.map do |hash_string|
          torrent = Torrent.find_by_hash_string(hash_string)
          next unless torrent

          torrent.mark_removed_from_client(transaction: t)
          torrent
        end.compact

        updated_torrents.concat(unlisted_torrents)

        # Update listed hashes in Redis
        unless transmission_hash_strings.empty?
          t.add_operation do |pipeline|
            pipeline.del(listed_key)
            pipeline.sadd(listed_key, transmission_hash_strings)
          end
        end

        # Update sync status and broadcast changes
        if updated_torrents.any?
          update(synced_at: Time.now, sync_error_name: nil, sync_error_msg: nil, transaction: t)
          t.on_complete do
            db_provider.update_cache(listed_key, transmission_hash_strings)
            self.class.broadcast(updated_torrents)
          end
        end
      end
    end

    def sync_error(e, transaction: nil)
      db_provider.write(transaction:) do |t|
        update(sync_error_name: e.class.name, sync_error_msg: e.to_s, transaction: t)
      end
    end

    def listed_hashes
      db_provider.read(listed_key) do |redis|
        redis.smembers(listed_key)
      end
    end

    def listed_key
      'tr:listed'
    end

    def is_stale?
      expected_delay = Registry.instance.options.transmission.poll_interval_sec
      synced_at.nil? || synced_at < (2 * expected_delay).seconds.ago
    end
  end
end
