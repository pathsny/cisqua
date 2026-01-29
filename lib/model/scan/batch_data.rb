# A record of a particular scan and the results
#
# @attr [String] request_source How the batch_data was triggered
# @attr [Integer] count the number of raw files in the batch
# @attr [Integer] snapshots_processed the number of mylist snapshots that were preserved
# @attr [Boolean] is_complete true if the batch_data is complete
# @attr [Array<RawFile>] files the raw files in the batch

require 'active_model'

module Cisqua
  class BatchData
    include Model::AutoIdKey
    include SemanticLogger::Loggable

    key_prefix :bd

    time_attrs :created_at
    string_attrs :request_source
    int_attrs :count
    incr_attrs :anime_snapshot_count
    bool_attrs :is_complete
    required_attrs :count, :created_at, :is_complete,
      :request_source, :anime_snapshot_count

    has_many :mylist_anime_snapshots, short_name: :snapshots, redis_key_part: :sns
    has_many :raw_files, redis_key_part: :rfs
    immutably_belongs_to :batch_check
    has_many :anime_name_changes, redis_key_part: :ancs

    validate :has_files

    on_save :modify_updated_index

    def has_files
      errors.add(:count, 'must have some files') unless count.positive?
    end

    def complete?
      is_complete
    end

    # A file from an Anime is being added to MyList
    # This is the place to capture a snapshot of the files of the anime
    def record_file_identity(anime_file)
      snapshot = MylistAnimeSnapshot.find_by_batch_data_id_and_aid(id, anime_file.aid)
      return unless snapshot.nil?

      db_provider.write do |transaction|
        MylistAnimeSnapshot.capture_mylist_data(
          batch_data_id: id,
          aid: anime_file.aid,
          transaction:,
        )
      end
    end

    def record_file_result(index, result:, **kwargs)
      db_provider.write do |transaction|
        raw_file = RawFile.find(id, index)
        raw_file.update(transaction:, result:, **kwargs)

        next if raw_file.file.nil?

        snapshot = MylistAnimeSnapshot.find(id, raw_file.file.aid)
        next unless snapshot.index.nil?

        snapshot.update(transaction:, index: anime_snapshot_count)
        incr(:anime_snapshot_count)
        save(transaction:)
      end
    end

    def processed_fids(aid, process_type)
      if process_type == :existing
        snapshot = MylistAnimeSnapshot.find(id, aid)
        snapshot.fids
      else
        raw_files.filter_map do |raw_file|
          raw_file.fid if raw_file.result == process_type && raw_file.file.aid == aid
        end
      end
    end

    def processed
      raw_files.count { |f| !f.result.nil? }
    end

    def replaced_fids(aid)
      raw_files.filter_map do |raw_file|
        next unless raw_file.result == :replacement && raw_file.file.aid == aid

        { new: raw_file.fid, old: raw_file.replaced_fid, reason: raw_file.reason }
      end
    end

    def final_fids(aid)
      fids = MylistAnimeSnapshot.find(id, aid).fids.to_a
      raw_files.each do |raw_file|
        next unless raw_file.file&.aid == aid

        fids << raw_file.fid if %i[success replacement].include?(raw_file.result)
        fids.delete(raw_file.replaced_fid) if raw_file.result == :replacement
      end
      fids
    end

    def anime_key
      "#{redis_key}:anime"
    end

    def sorted_anime_ids
      snapshots.filter(&:index).sort_by(&:index).map(&:aid)
    end

    def self.make(source_count:, transaction: nil, **attrs)
      db_provider.write(transaction:) do |t|
        instance = create(
          transaction: t,
          count: source_count,
          is_complete: false,
          **attrs,
        )
        source_count.times do |index|
          RawFile.new.update(
            transaction: t,
            batch_data_id: instance.id,
            index:,
            name: yield(index),
          )
        end
        instance
      end
    end

    def self.updated_since(start_time)
      db_provider.bypass_cache do |redis|
        redis.zrevrangebyscore('bd:timestamps', '+inf', start_time.to_i + 1).map do |id|
          find(id)
        end
      end
    end

    def modify_updated_index(_operation, transaction)
      return unless updated_at_changed?

      db_provider.write(transaction:) do |t|
        t.add_operation do |pipeline|
          pipeline.zadd('bd:timestamps', updated_at.to_i, id)
        end
      end
    end
  end
end
