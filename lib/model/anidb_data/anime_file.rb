# An Identified AnimeFile with data from Anidb

module Cisqua
  class AnimeFile
    include Model::AnidbDataModelWithID
    include SemanticLogger::Loggable

    key_prefix :fid

    int_attrs :version, :length
    string_attrs :aid, :eid, :gid, :other_episodes, :state, :quality, :source,
      :video_resolution, :dub_language, :sub_language
    symbol_attrs :crc_status, :censored

    immutably_belongs_to :anime, foreign_key: :aid
    immutably_belongs_to :group, foreign_key: :gid
    has_one :anime_file_misc, foreign_key: :id, short_name: :misc
    has_many :episodes, short_id_name: :eids, custom_id_method: :_eids

    def _eids
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
  end
end
