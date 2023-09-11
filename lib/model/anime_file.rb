module Cisqua
  class AnimeFile
    include Model::AnidbDataModelWithID

    key_prefix :fid

    int_attrs :version, :length
    string_attrs :aid, :eid, :gid, :other_episodes, :state, :quality, :source,
      :video_resolution, :dub_language, :sub_language
    symbol_attrs :crc_status, :censored

    after_save :save_associations

    def eids
      other_eids = (other_episodes || '').split('\'').map do |segment|
        segment.split(',').first
      end
      [eid, *other_eids]
    end

    def episodes
      eids.map do |episode_id|
        Episode.find(episode_id)
      end
    end

    def epno
      epnos = episodes.filter { |ep| ep.aid == aid }.map(&:epno).sort
      return epnos.first if epnos.size == 1

      main_episode = Episode.find(eid)
      return main_episode.epno if main_episode.special?

      [epnos.first, epnos.last].join('-')
    end

    def anime
      Anime.find(aid)
    end

    def misc
      AnimeFileMisc.find(id)
    end

    def group
      Group.find(gid)
    end

    def save_associations
      eids.each do |ep_id|
        redis.sadd("eid:#{ep_id}:files", @id)
      end
      redis.sadd("gid:#{gid}:files", @id)
      redis.sadd("gid:#{gid}:anime", @aid)
      redis.sadd("aid:#{aid}:groups", @gid)
    end
  end
end
