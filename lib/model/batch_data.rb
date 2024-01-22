require 'active_model'
require_relative 'redisable'
require_relative 'saveable'

module Cisqua
  class BatchData
    include Model::IDKeyable
    include SemanticLogger::Loggable

    time_attrs :created_at
    string_attrs :request_source
    int_attrs :count, :processed
    bool_attrs :is_complete
    other_required_attrs :request_source, :count,
      :is_complete, :processed, :created_at
    hash_attrs :replacements

    key_prefix :bd

    validate :has_files
    after_save :save_associations

    def has_files
      errors.add(:count, 'must have some files') unless count.positive?
    end

    def complete?
      is_complete
    end

    # Records a snapshot of fids in mylist.
    # Also takes a list of fids to exclude or include in case they were already
    # in mylist
    def record_files_snapshot(aid, fids_to_exclude: [], fids_to_include: [])
      existing = MyList.fids(aid) - fids_to_exclude + fids_to_include
      return if existing.empty?

      key = make_key_for_anime_updates(aid, :existing)
      redis.sadd(key, *existing)
    end

    def record_progress(
      aid,
      success: [],
      dups: [],
      junk: [],
      replacement: nil
    )
      score = redis.zscore(anime_key, aid)
      if score.nil?

        # the anime has not been stored
        redis.zadd(anime_key, redis.zcard(anime_key), aid)
        record_files_snapshot(
          aid,
          fids_to_exclude: success + [
            replacement&.dig([], :new),
          ].compact,
          fids_to_include: [replacement&.dig([], :old)].compact,
        )
      end
      values = { success:, dups:, junk: }
      %i[success dups junk].each do |k|
        value = values[k]
        next if value.nil? || value == []

        key = make_key_for_anime_updates(aid, k)
        redis.sadd(key, value)
      end

      updates = {
        processed: processed + success.count + dups.count + junk.count + (replacement ? 1 : 0),
      }
      if replacement
        updates[:replacements] = (replacements || {}).merge(
          aid => replaced_fids(aid).push(replacement),
        )
      end

      update(updates)
    end

    def add_unknown(name)
      redis.rpush(unknown_key, name)
      update(processed: processed + 1)
    end

    def unknowns
      redis.lrange(unknown_key, 0, -1)
    end

    def processed_fids(aid, process_type)
      redis.smembers(make_key_for_anime_updates(aid, process_type))
    end

    def replaced_fids(aid)
      replacements&.dig(aid)&.map(&:symbolize_keys) || []
    end

    def final_fids(aid)
      previous = redis.smembers(make_key_for_anime_updates(aid, :existing))
      success = redis.smembers(make_key_for_anime_updates(aid, :success))
      plucked_fids = replaced_fids(aid).map { |r| [r[:new], r[:old]] }
      added, removed = plucked_fids.empty? ? [[], []] : plucked_fids.transpose
      previous + success + added - removed
    end

    def make_key_for_anime_updates(aid, update_type)
      "#{make_key_for_instance}:#{update_type}:#{aid}"
    end

    def anime_key
      "#{make_key_for_instance}:anime"
    end

    def unknown_key
      "#{make_key_for_instance}:unknown"
    end

    def affected_anime_ids
      redis.zrange(anime_key, 0, -1, rev: true)
    end

    def self.latest(count)
      return [] if count != :all && count.zero?

      limit = if count == :all
        -1
      elsif count.negative? # most likely the caller is using -1
        count
      else
        count - 1
      end
      redis.zrange('bd:timestamps', 0, limit, rev: true).map { |id| BatchData.find(id) }
    end

    def self.updated_since(timestamp)
      redis.zrangebyscore('bd:timestamps', timestamp + 1, '+inf').map { |id| BatchData.find(id) }
    end

    def self.create(request_source, count)
      id = redis.incr('bd:last_id').to_s
      created_at = Time.now
      instance = new
      instance.update(
        id:,
        created_at:,
        count:,
        processed: 0,
        is_complete: false,
        request_source:,
        updated_at: created_at,
      )
    end

    def save_associations
      redis.zadd('bd:timestamps', created_at.to_i, id)
    end
  end
end
