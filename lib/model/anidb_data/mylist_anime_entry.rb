module Cisqua
  class MyListAnimeEntry
    include Model::Saveable
    include SemanticLogger::Loggable

    string_attrs :aid
    index_attrs :aid

    immutably_belongs_to :my_list, id_attribute: :aid
    immutably_belongs_to :anime, foreign_key: :aid, one_way: true
    has_many :anime_files, short_name: :files, short_id_name: :fids, one_way: true

    def self.make_key(aid)
      "mylist:aid:#{aid}"
    end

    def eids
      files.map(&:eid).uniq
    end

    def episodes
      eids.map { |id| Episode.find(id) }
    end

    def complete?
      assert(!anime.movie?, 'not supported for movies yet')
      return false unless anime.ended?

      epnos = episodes.reject(&:special?).map(&:epno).map do |x|
        Integer(x.sub(/^0+/, ''), 10)
      end
      epnos = epnos.to_set
      (1..anime.episode_count).all? { |epno| epnos.include?(epno) }
    end
  end
end
