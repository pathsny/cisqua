module Cisqua
  class MyList
    include Model::Saveable
    include SemanticLogger::Loggable

    has_many :my_list_anime_entries, short_name: :entries, short_id_name: :entry_ids, redis_key_part: :animes
    has_many :animes, id_alias: :my_list_anime_entries, short_id_name: :aids

    single_instance 'mylist'

    def self.instance
      find
    end

    def add_file(fid, transaction: nil)
      file = AnimeFile.find(fid)
      name = file.anime.romaji_name
      db_provider.write(transaction:) do |t|
        entry = MyListAnimeEntry.upsert(aid: file.aid, transaction: t)
        entry.files.add(file, transaction: t)
        t.add_operation do |pipeline|
          pipeline.zadd(animes_sorted_key, 1, "#{name}:#{file.aid}")
        end
      end
    end

    def remove_file(fid, transaction: nil)
      file = AnimeFile.find(fid)

      name = file.anime.romaji_name
      db_provider.write(transaction:) do |t|
        entry = MyListAnimeEntry.find(file.aid)
        entry.files.remove(file, transaction: t)
        t.add_operation do |pipeline|
          pipeline.zrem(animes_sorted_key, "#{name}:#{file.aid}")
        end
      end
    end

    def animes_sorted_key
      'mylist:sorted:animes'
    end

    def animes_search_sorted(search_term, cursor = nil, limit = 10)
      result, next_cursor = db_provider.bypass_cache do |redis|
        if cursor
          redis.call(
            'FT.CURSOR',
            'READ',
            'name_index',
            cursor,
          )
        else
          redis.call(
            'FT.AGGREGATE',
            'name_index',
            "*#{search_term}*",
            'LOAD',
            1,
            '@__key',
            'SORTBY',
            '1',
            '@romaji_name',
            'WITHCURSOR',
            'COUNT',
            limit,
            'LIMIT',
            '0',
            '1000',
          )
        end
      end
      count, *values = result
      known_animes = values.map { |r| Hash[*r]['__key'] }.map { |k| Anime.find_by_key(k) }
      animes = known_animes.filter { |anime| entry_ids.include?(anime.id) }
      next_cursor = nil if next_cursor.zero?
      { next_cursor:, animes:, count: }
    end

    def anime_ids_sorted(cursor = nil, limit = 10)
      db_provider.bypass_cache do |redis|
        count = redis.zcount(animes_sorted_key, '-inf', '+inf') unless cursor
        start_range = cursor ? "(#{cursor}" : '-'
        raw_data = redis.zrangebylex(
          animes_sorted_key,
          start_range,
          '+',
          limit: [0, limit],
        )
        anime_ids = raw_data.map { |value, _score| value.split(':').last }
        next_cursor = raw_data.length == limit ? raw_data.last : nil
        { anime_ids:, next_cursor:, count: }
      end
    end

    def animes_sorted(cursor = nil, limit = 10)
      anime_ids_sorted(cursor, limit) => {anime_ids:, next_cursor:, count: }
      animes = anime_ids.map { |aid| Anime.find(aid) }
      { animes:, next_cursor:, count: }
    end

    def exist?(fid)
      file = AnimeFile.find(fid)
      entries[file.aid]&.fids&.include?(fid)
    end

    def update_anime_name(aid, old_name, new_name, transaction: nil)
      db_provider.write(transaction:) do |t|
        t.add_operation do |pipeline|
          pipeline.zrem(animes_sorted_key, "#{old_name}:#{aid}")
          pipeline.zadd(animes_sorted_key, 1, "#{new_name}:#{aid}")
        end
      end
    end
  end
end
