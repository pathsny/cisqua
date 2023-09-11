module Cisqua
  class AnimeFileMisc
    include Model::AnidbDataModelWithID
    include SemanticLogger::Loggable

    key_prefix 'fid:misc'
    int_attrs :highest_episode_number
    string_attrs :year, :type, :romaji_name,
      :english_name, :epno, :ep_english_name, :ep_romaji_name,
      :group_name, :group_short_name

    validate :data_matches_other_models

    def main_file
      AnimeFile.find(id)
    end

    def anime
      main_file.anime
    end

    def episodes
      main_file.episodes
    end

    def group
      main_file.group
    end

    def expected_value(field_name)
      case field_name
      when :highest_episode_number
        anime.highest_episode_number
      when :year
        anime.year
      when :type
        anime.type
      when :romaji_name
        anime.romaji_name
      when :english_name
        anime.english_name
      when :epno
        main_file.epno
      when :ep_english_name
        episodes.first.english_name
      when :ep_romaji_name
        episodes.first.romaji_name
      when :group_name
        group.name
      when :group_short_name
        group.short_name
      end
    end

    def data_matches_other_models
      self.class.attr_list.each do |field|
        next if %i[id updated_at data_source].include? field

        actual = instance_values[field.to_s]
        expected = expected_value(field)
        if actual != expected
          errors.add(field, "value #{actual} does not match expected value #{expected}")
        end
      end
    end
  end
end
