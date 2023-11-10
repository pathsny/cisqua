require 'active_model'
require_relative 'redisable'
require_relative 'saveable'

module Cisqua
  class BatchData
    include Model::IDKeyable
    include SemanticLogger::Loggable

    time_attrs :created_at
    string_attrs :request_source
    int_attrs :count
    bool_attrs :is_complete
    other_required_attrs :request_source, :count,
      :is_complete, :created_at

    key_prefix :bd

    validate :has_files
    after_save :save_associations

    def has_files
      errors.add(:count, 'must have some files') unless count.positive?
    end

    def progress
      "#{unknowns.count + success_fids.count}/#{count}"
    end

    def complete?
      is_complete
    end

    def add_success_fid(fid)
      redis.rpush(success_key, fid)
    end

    def success_fids
      redis.lrange(success_key, 0, -1)
    end

    def add_duplicate_fids(fids)
      redis.rpush(duplicate_key, fids)
    end

    def duplicate_fids
      redis.lrange(duplicate_key, 0, -1)
    end

    def add_replacement_fid(fid)
      redis.rpush(replacement_key, fid)
    end

    def replacement_fids
      redis.lrange(replacement_key, 0, -1)
    end

    def add_unknown(name)
      redis.rpush(unknown_key, name)
      update({}) # ensure the updated_at date changes
    end

    def unknowns
      redis.lrange(unknown_key, 0, -1)
    end

    def unknown_key
      "#{make_key_for_instance}:unknown"
    end

    def success_key
      "#{make_key_for_instance}:success"
    end

    def duplicate_key
      "#{make_key_for_instance}:duplicate"
    end

    def replacement_key
      "#{make_key_for_instance}:replacement"
    end

    def self.latest(count)
      redis.zrange('bd:timestamps', 0, count - 1, rev: true).map { |id| BatchData.find(id) }
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
        is_complete: false,
        request_source:,
        updated_at: created_at,
      )
    end

    def save_associations
      redis.zadd('bd:timestamps', updated_at.to_i, id)
    end

  end
end
