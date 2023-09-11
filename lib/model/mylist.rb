module Cisqua
  class MyList
    include Model::Redisable

    class << self
      def add_file(fid)
        file = AnimeFile.find(fid)
        name = file.anime.romaji_name
        redis.sadd(animes_key, file.aid)
        redis.zadd(animes_sorted_key, 1, "#{name}:#{file.aid}")
        redis.sadd(files_key(file.aid), fid)
      end

      def animes_key
        'mylist:animes'
      end

      def animes_sorted_key
        'mylist:sorted:animes'
      end

      def files_key(aid)
        "mylist:aid:#{aid}:files"
      end

      def anime_ids
        redis.smembers(animes_key)
      end

      def anime_ids_sorted(limit = nil)
        redis.zrange(animes_sorted_key, 0, limit || -1).map { |value| value.split(':').last }
      end

      def animes
        anime_ids.map { |id| Anime.find(id) }
      end

      def animes_sorted(limit = nil)
        anime_ids_sorted(limit).map { |id| Anime.find(id) }
      end

      def fids(aid)
        redis.smembers(files_key(aid))
      end

      def files(aid)
        fids(aid).map { |id| AnimeFile.find(id) }
      end

      def eids(aid)
        files(aid).map(&:eid).uniq
      end

      def episodes(aid)
        eids(aid).map { |id| Episode.find(id) }
      end

      def exist?(fid)
        file = AnimeFile.find(fid)
        redis.sismember(animes_key, file.aid) &&
          redis.sismember(files_key(file.aid), fid)
      end

      def complete?(aid)
        anime = Anime.find(aid)
        assert(!anime.movie?, 'not supported for movies yet')
        return false unless anime.ended?

        epnos = episodes(aid).reject(&:special?).map(&:epno).map do |x|
          Integer(x.sub(/^0+/, ''))
        end
        epnos = epnos.to_set
        (1..anime.episode_count).all? { |epno| epnos.include?(epno) }
      end

      def make_range(aid); end

      def update_anime_name(aid, old_name, new_name)
        redis.zrem(animes_sorted_key, "#{old_name}:#{aid}")
        redis.zadd(animes_sorted_key, 1, "#{new_name}:#{aid}")
      end
    end
  end
end
