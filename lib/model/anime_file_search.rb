module Cisqua
  class AnimeFileSearch
    include Model::AnidbDataModel
    include SemanticLogger::Loggable

    string_attrs :ed2k, :size, :fid
    time_attrs :updated_at
    unique_attrs :ed2k, :size
    attr_accessor :data_source

    def file
      return nil unless known?

      AnimeFile.find(fid)
    end

    def known?
      !fid.nil?
    end

    def self.make_key(ed2k, size)
      "ed2k:#{ed2k}:size:#{size}"
    end
  end
end
