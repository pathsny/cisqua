# update the redis db after schema change
require File.expand_path('../lib/libs', __dir__)
require File.join(Cisqua::ROOT_FOLDER, 'integration_spec', 'test_util')
require 'optparse'

module Cisqua
  class FixDBForRanges
    def run
      reset_batch_order

      success_map = {}
      batch_ids.each do |bd_id|
        bd_key = BatchData.make_key(bd_id)
        assert(redis.lrange("#{bd_key}:replacement", 0, -1).empty?, 'no replacements')
        success_fids = redis.lrange("#{bd_key}:success", 0, -1)
        duplicate_fids = redis.lrange("#{bd_key}:duplicate", 0, -1)
        if success_fids.empty? && duplicate_fids.empty?
          delete_unused(bd_id, bd_key)
        else
          added_success_map = migrate_fields(
            bd_id,
            bd_key,
            success_fids,
            duplicate_fids,
            success_map,
          )
          added_success_map.each do |aid, fids|
            success_map[aid] = ((success_map[aid] || []) + fids).uniq
          end
          cleanup_old_fields(bd_id, bd_key)
        end
      rescue StandardError, SolidAssert::AssertionFailedError => e
        puts "got error #{e} for #{bd_id}"
        raise e
      end
    end

    def reset_batch_order
      # reset the ordering since we were once not using created_at
      batch_ids.each do |bd_id|
        created_time = redis.hget(BatchData.make_key(bd_id), 'created_at')
        redis.zadd('bd:timestamps', created_time, bd_id)
      end
    end

    def batch_ids
      redis.zrange('bd:timestamps', 0, -1, rev: true)
    end

    def redis
      Registry.instance.redis
    end

    def delete_unused(bd_id, bd_key)
      updates = redis.hgetall(bd_key)['updates_json_str']
      assert(updates.nil?, 'no updates')
      related_redis_keys = redis.keys("#{bd_key}:*")
      assert(related_redis_keys.empty?, 'not yet supported')
      redis.zrem('bd:timestamps', bd_id)
      redis.del(bd_key)
    end

    def migrate_fields(_bd_id, bd_key, success_fids, duplicate_fids, success_map)
      updates = JSON.parse(redis.hgetall(bd_key)['updates_json_str'])
      captured_aids = updates.keys
      success_fids_grpd = success_fids.group_by { |fid| AnimeFile.find(fid).aid }
      duplicate_fids_grpd = duplicate_fids.group_by { |fid| AnimeFile.find(fid).aid }
      expected_aids = (success_fids_grpd.keys + duplicate_fids_grpd.keys).uniq
      assert(
        (expected_aids - captured_aids).empty? &&
        (captured_aids - expected_aids).empty? &&
        captured_aids.size == expected_aids.size,
        'these should be identical as the list of animes',
      )

      # set affected_anime_ids
      anime_key = "#{bd_key}:anime"
      captured_aids.each_with_index do |aid, _idx|
        score = redis.zscore(anime_key, aid)

        if score.nil?
          score_to_set = redis.zcard(anime_key)
          redis.zadd(anime_key, score_to_set, aid)
        end

        if success_fids_grpd.key?(aid)
          success_key = "#{bd_key}:success:#{aid}"
          redis.sadd(success_key, *success_fids_grpd[aid])
        end

        if duplicate_fids_grpd.key?(aid)

          # in the new schema junk and dups are different. Most duplicates were
          # junk, so thats just assumed here.
          junk_key = "#{bd_key}:junk:#{aid}"
          redis.sadd(junk_key, *duplicate_fids_grpd[aid])
        end

        existing_key = "#{bd_key}:existing:#{aid}"
        redis.spop(existing_key) while redis.scard(existing_key).positive?

        fids_to_exclude = (success_map[aid] || []) + (success_fids_grpd[aid] || [])
        existing_fids = MyList.fids(aid) - fids_to_exclude
        redis.sadd(existing_key, *existing_fids) unless existing_fids.empty?
      end

      affected_anime_ids = redis.zrange(anime_key, 0, -1, rev: true)
      success_count = 0
      junk_count = 0
      affected_anime_ids.each do |aid|
        success_count += redis.smembers("#{bd_key}:success:#{aid}").count
        junk_count += redis.smembers("#{bd_key}:junk:#{aid}").count
      end
      unknowns_count = redis.lrange("#{bd_key}:unknown", 0, -1).count

      redis.hset(bd_key, { processed: unknowns_count + success_count + junk_count })

      success_fids_grpd
    end

    def cleanup_old_fields(_bd_id, bd_key)
      redis.hdel(bd_key, :updates_json_str)
      redis.del("#{bd_key}:success")
      redis.del("#{bd_key}:duplicate")
      redis.del("#{bd_key}:replacement")
    end
  end

  script_options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: fix_db_for_ranges'
    opts.on('-t', '--test', 'run for testing') do
      script_options[:test_mode] = true
    end
    opts.on('-s', '--start-redis', 'starts and stops redis server') do
      script_options[:start_redis] = true
    end
  end.parse!

  Registry.options_file_override = script_options[:options_file]
  if script_options[:test_mode]
    TestUtil.prep_registry
  end
  registry = Registry.instance
  if script_options[:start_redis]
    RedisScripts.instance.with_redis(registry.options.redis.conf_path) do
      FixDBForRanges.new.run
    end
  else
    FixDBForRanges.new.run
  end
end
