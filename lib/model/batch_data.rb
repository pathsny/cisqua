require 'active_model'
require_relative 'redisable'
require_relative 'saveable'

module Cisqua
  class BatchData
    include Model::IDKeyable
    include SemanticLogger::Loggable

    time_attrs :created_at
    string_attrs :request_source, :updates_json_str
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
      calculate_updates_json(AnimeFile.find(fid).anime)
    end

    def success_fids
      redis.lrange(success_key, 0, -1)
    end

    def add_duplicate_fids(fids)
      redis.rpush(duplicate_key, fids)
      calculate_updates_json(AnimeFile.find(fids.first).anime)
    end

    def duplicate_fids
      redis.lrange(duplicate_key, 0, -1)
    end

    def add_replacement_fid(fid)
      redis.rpush(replacement_key, fid)
      calculate_updates_json(AnimeFile.find(fid).anime)
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

    def updates_json
      updates_json_str.nil? ? {} : JSON.parse(updates_json_str)
    end

    # Updates the json based on the latest state of success, duplicates etc and
    # the current state of mylist.
    # if this is recomputed in the future, it will likely be incorrect since the mylist
    # will have additional data
    def calculate_updates_json(anime)
      updates_json = updates_json_str ? JSON.parse(updates_json_str) : {}

      latest = MakeRange.new.parts_with_groups_strings(
        anime.id,
        MyList.files(anime.id),
      )

      updates_json[anime.id] = {
        latest:,
        **calculate_updates(anime, success_fids, :success),
        **calculate_updates(anime, duplicate_fids, :duplicate),
        **calculate_updates(anime, replacement_fids, :replacement),
      }
      update(
        updates_json_str: updates_json.to_json,
      )
    end

    def calculate_updates(anime, fids_attr, name)
      files = fids_attr.map { |fid| AnimeFile.find(fid) }.filter { |file| file.aid == anime.id }
      return {} if files.empty?

      {
        name => MakeRange.new.parts_with_groups_strings(
          anime.id,
          files,
        ),
      }
    end
  end
end
