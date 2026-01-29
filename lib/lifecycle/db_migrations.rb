module Cisqua
  class DbMigrations
    extend Cisqua::Reloadable
    include SemanticLogger::Loggable
    include Singleton

    reloadable_const_define :CURRENT_VERSION, 4

    def run
      version = fetch_version

      while version < CURRENT_VERSION
        logger.info('DB Version is behind', version:, current_version: CURRENT_VERSION)
        version += 1
        migrations(version)
      end
    end

    def migrations(version)
      logger.info('running migrations to get to ', version:)
      method_name = "migration_#{version.to_s.rjust(3, '0')}"
      assert(respond_to?(method_name), "Missing migration #{method_name}")
      send(method_name)

      redis.hset('root', { version:, updated_at: Time.now.to_i })
    end

    def migration_001
      step('create name index', !index_exists?('name_index')) do
        create_index('name_index')
      end
    end

    def migration_002
      step('create mylist', !redis.exists?('mylist')) do
        redis.hset('mylist', { updated_at: Time.now.to_i })
      end
      step('modify batch data', batch_data_below_version_002?) do
        update_batch_data_to_version_002
      end
      step('modify batch check', redis.exists?('bc:latest')) do
        update_batch_check_to_version_002
      end
      step('create mylist entries', !redis.exists?('mylist:aid:*')) do
        create_mylist_entries
      end
      step('create library', !redis.exists?('lib')) do
        create_library
      end
    end

    def migration_003
      step('confirm batchcheck has batch_data_ids', batch_check_missing_batch_data_ids?) do
        fix_batch_check_batch_data_ids
      end
      step('update batchdata timestamps index', batchdata_timestamps_index_incorrect?) do
        fix_batchdata_timestamps_index
      end
    end

    def migration_004
      step('set batch_data auto_id_key', !redis.hget('bc', 'bd_count').nil?) do
        count = redis.hget('bc', 'bd_count').to_i
        redis.set('bd_count', count)
        redis.hdel('bc', 'bd_count')
      end
    end

    def batch_check_missing_batch_data_ids?
      redis.scard('bc:bds') != redis.zcard('bd:timestamps')
    end

    def fix_batch_check_batch_data_ids
      redis.zrange('bd:timestamps', 0, -1).each do |bd_id|
        redis.sadd('bc:bds', bd_id)
      end
    end

    def batchdata_timestamps_index_incorrect?
      redis.smembers('bc:bds').any? do |bd_id|
        redis.zscore('bd:timestamps', bd_id).to_i != redis.hget("bd:#{bd_id}", 'updated_at').to_i
      end
    end

    def fix_batchdata_timestamps_index
      redis.smembers('bc:bds').each do |bd_id|
        redis.zadd('bd:timestamps', redis.hget("bd:#{bd_id}", 'updated_at').to_i, bd_id)
      end
    end

    def batch_data_below_version_002?
      return false if redis.keys('bd:*').empty?

      ids = redis.keys('bd:*').map { |key| key[/^bd:(\d+)$/, 1] }
        .compact
        .map(&:to_i)

      redis.hgetall("bd:#{ids.last}").key?('processed')
    end

    def update_batch_data_to_version_002
      # Extract numeric IDs using regex
      ids = redis.keys('bd:*').map { |key| key[/^bd:(\d+)$/, 1] }
        .compact
        .map(&:to_i)

      ids.each do |id|
        next unless redis.hgetall("bd:#{id}").key?('processed')

        logger.debug('updating batch data', id:)
        data = redis.hgetall("bd:#{id}")
        unknowns = redis.lrange("bd:#{id}:unknown", 0, -1)
        aids = redis.zrange("bd:#{id}:anime", 0, -1)
        assert(
          data['processed'] == data['count'],
          "batch_data #{id} is not complete #{data['processed']} != #{data['count']}",
        )
        success = []
        duplicate = []
        junk = []
        existing_fids = []
        aids.each do |aid|
          success += redis.smembers("bd:#{id}:success:#{aid}").map { |fid| { aid:, fid: } }
          duplicate += redis.smembers("bd:#{id}:duplicate:#{aid}").map { |fid| { aid:, fid: } }
          junk += redis.smembers("bd:#{id}:junk:#{aid}").map { |fid| { aid:, fid: } }
          existing_fids << {
            aid:,
            fids: redis.smembers("bd:#{id}:existing:#{aid}"),
          }
        end
        identified = success.count + duplicate.count + junk.count + unknowns.count
        assert(
          data['count'].to_i == identified,
          "expected #{data['count']} to be identified #{identified}",
        )
        assert(
          data['replacements'].nil?,
          'not implementing for replacements yet',
        )
        rf_index = -1
        sn_index = -1
        unknowns.each do |unknown|
          rf_index += 1
          rk = raw_key(id, rf_index)
          next if redis.exists?(rk)

          redis.hset(rk, {
            name: unknown,
            result: :unknown,
            batch_data_id: id,
            index: rf_index,
          })
          redis.sadd("bd:#{id}:rfs", rf_index)
        end
        aids.each do |aid|
          snk = snapshot_key(id, aid)
          sn_index += 1
          next if redis.exists?(snk)

          redis.hset(snk, {
            aid:,
            batch_data_id: id,
            index: sn_index,
          })
          redis.sadd("bd:#{id}:sns", aid)
          existing = existing_fids.find { |ef| ef[:aid] == aid }[:fids]
          unless existing.empty?
            redis.sadd("#{snk}:files", existing)
          end
        end

        success.each do |s|
          rf_index += 1
          rk = raw_key(id, rf_index)

          redis.hset(rk, {
            name: "unknown_bd_#{id}_#{rf_index}",
            fid: s[:fid],
            batch_data_id: id,
            index: rf_index,
            result: :success,
          })
          redis.sadd("bd:#{id}:rfs", rf_index)
        end
        duplicate.each do |d|
          rf_index += 1
          rk = raw_key(id, rf_index)

          redis.hset(rk, {
            name: "unknown_duplicate_bd_#{id}_#{rf_index}",
            fid: d[:fid],
            batch_data_id: id,
            index: rf_index,
            result: :duplicate,
          })
          redis.sadd("bd:#{id}:rfs", rf_index)
        end

        junk.each do |j|
          rf_index += 1
          rk = raw_key(id, rf_index)

          redis.hset(rk, {
            name: "unknown_junk_bd_#{id}_#{rf_index}",
            fid: j[:fid],
            batch_data_id: id,
            index: rf_index,
            result: :junk,
          })
          redis.sadd("bd:#{id}:rfs", rf_index)
        end

        assert(
          rf_index + 1 == data['count'].to_i,
          "expected #{data['count']} to be identified #{identified}",
        )
        assert(
          sn_index + 1 == aids.count,
          "expected #{aids.count} to be identified #{sn_index}",
        )
        redis.hset("bd:#{id}", {
          anime_snapshot_count: aids.count,
          is_complete: true.to_s,
        })
        redis.hdel("bd:#{id}", 'processed')
      end
    end

    def snapshot_key(batch_data_id, aid)
      "bd:#{batch_data_id}:sn:#{aid}"
    end

    def raw_key(batch_data_id, index)
      "bd:#{batch_data_id}:raw:#{index}"
    end

    def update_batch_check_to_version_002
      prev = redis.hgetall('bc:latest')
      id = redis.get('bd:last_id')
      redis.hset('bc', {
        request_source: prev['request_source'],
        updated_at: prev['updated_at'],
        bd_count: id,
      })
      redis.del('bc:latest')
      redis.del('bd:last_id')
    end

    def create_mylist_entries
      redis.smembers('mylist:animes').each do |aid|
        redis.hset(
          "mylist:aid:#{aid}",
          {
            aid:,
            updated_at: Time.now.to_i,
          },
        )
      end
    end

    def create_library
      redis.hset('lib', { updated_at: Time.now.to_i })
      aids = redis.keys('aid:*').map { |key| key[/^aid:(\d+)$/, 1] }
        .compact
        .map(&:to_i)
      redis.sadd('lib:animes', *aids)
      gids = redis.keys('gid:*').map { |key| key[/^gid:(\d+)$/, 1] }
        .compact
        .map(&:to_i)
      redis.sadd('lib:groups', *gids)
    end

    def fetch_version
      stored_version = redis.hgetall('root')&.[]('version')
      return 0 if stored_version.nil?

      stored_version.to_i
    end

    def step(name, condition_to_run)
      logger.info('testing for migration step', name:, condition_to_run:)
      return unless condition_to_run

      logger.info('running migration step', name:)
      yield
    end

    def index_exists?(index_name)
      redis.call('FT.INFO', index_name)
      true
    rescue Redis::CommandError => e
      return false if e.message.include?('Unknown index name')

      raise e
    end

    def create_index(index_name)
      redis.call('FT.CREATE', index_name, 'ON', 'HASH',
        'PREFIX', 1, 'aid:', 'SCHEMA',
        'english_name', 'TEXT', 'NOSTEM', 'SORTABLE',
        'romaji_name', 'TEXT', 'NOSTEM', 'SORTABLE')
    end

    def redis
      Registry.instance.redis
    end
  end
end
