# lib/model/scan/anime_name_change.rb
module Cisqua
  class AnimeNameChange
    include Model::Saveable
    include SemanticLogger::Loggable

    string_attrs :old_name, :new_name, :aid, :batch_data_id
    required_attrs :old_name, :new_name, :aid
    index_attrs :batch_data_id, :aid

    immutably_belongs_to :batch_data, foreign_key: :batch_data_id, id_attribute: :aid
    immutably_belongs_to :anime, foreign_key: :aid, id_attribute: :aid

    validate :names_are_different

    def names_are_different
      errors.add(:base, 'old and new names must be different') if old_name == new_name
    end

    def self.make_key(batch_data_id, aid)
      "bd:#{batch_data_id}:anc:#{aid}"
    end
  end
end
