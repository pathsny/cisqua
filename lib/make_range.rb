module Cisqua
  class MakeRange
    def contiguity_data(episode)
      if could_use_movie_numbering(episode)
        case episode.english_name
        when /Complete Movie/
          return { category: :complete_movie, num: nil }
        when /Part (?<p_num>\d) of (?<p_count>\d)/
          m = Regexp.last_match
          return {
            category: :movie_parts,
            num: Integer(m[:p_num]),
            count: Integer(m[:p_count]),
          }
        end
      end
      match = /^(?<spc_type>[A-Z])?(?<num>\d+)$/.match(episode.epno)
      {
        category: match[:spc_type] || :normal,
        num: Integer(match[:num].sub(/^[0]*/, '')),
      }
    end

    def could_use_movie_numbering(episode)
      episode.anime.movie? && !episode.special?
    end

    def contiguous?(entry_1, entry_2)
      return false if entry_1[:category] != entry_2[:category]

      case entry_1[:category]
      when :complete_movie
        assert(false, 'two complete movies cant be contiguous')
      when :movie_parts
        return false if entry_1[:count] != entry_2[:count]
      end
      entry_1[:num] + 1 == entry_2[:num]
    end

    def same_groups?(groups1, groups2)
      groups1.map(&:id).sort == groups2.map(&:id).sort
    end

    def contiguous_with_group?(entry_1, entry_2)
      contiguous?(entry_1, entry_2) && same_groups?(entry_1[:groups], entry_2[:groups])
    end

    def make_ranges_string_for_complete_movie(range_parts)
      assert(
        range_parts.size == 1,
        'there should only be one range part',
      )
      range_part = range_parts.first
      assert(
        range_part[:start].id == range_part[:stop].id,
        'there can be only one complete movie',
      )
      yield(range_part, range_part[:start].english_name)
    end

    def make_ranges_string_for_episodes(range_parts)
      range_part_strings = range_parts.map do |range_part|
        range_part => {start:, stop: }
        str = start.id == stop.id ? start.epno : "#{start.epno}-#{stop.epno}"
        block_given? ? yield(range_part, str) : str
      end
      prefix = 'Episodes'
      if range_parts.count == 1
        range_parts.first => {start:, stop: }
        if start.id == stop.id
          prefix = 'Episode'
        end
      end
      "#{prefix} #{range_part_strings.join(', ')}"
    end

    def make_ranges_string_for_movie_parts(range_parts)
      range_part_strings = range_parts.map do |range_part|
        range_part => {start:, stop:, count:, start_num:, stop_num: }
        str = if start.id == stop.id
          start.english_name
        else
          "Parts #{start_num}-#{stop_num} of #{count}"
        end
        block_given? ? yield(range_part, str) : str
      end
      range_part_strings.join(', ')
    end

    def make_ranges_string(range_parts)
      range_parts_by_type = range_parts.group_by do |p|
        case p[:category]
        when :complete_movie
          :complete_movie
        when :movie_parts
          "movie part of #{p[:count]}"
        else
          :episode
        end
      end
      ranges_strings = []
      range_part_types = range_parts_by_type.keys
      if range_part_types.include?(:complete_movie)
        ranges_string = make_ranges_string_for_complete_movie(
          range_parts_by_type[:complete_movie],
        ) { |range_part, str| block_given? ? yield(range_part, str) : str }
        ranges_strings << ranges_string
      end
      (range_part_types - %i[complete_movie episode]).each do |type|
        range_parts_for_movie_in_parts = range_parts_by_type[type]
        ranges_string = make_ranges_string_for_movie_parts(
          range_parts_for_movie_in_parts,
        ) { |rp, str| block_given? ? yield(rp, str) : str }
        ranges_strings << ranges_string
      end
      if range_part_types.include?(:episode)
        ranges_string = make_ranges_string_for_episodes(
          range_parts_by_type[:episode],
        ) { |range_part, str| block_given? ? yield(range_part, str) : str }
        ranges_strings << ranges_string
      end

      ranges_strings.join(', ')
    end

    def parts_with_groups(aid, files)
      episode_map = {}

      files.each do |file|
        relevant_episodes = file.episodes.select { |ep| ep.aid == aid }
        relevant_episodes.each do |ep|
          episode_map[ep.id] ||= { episode: ep, groups: [], **contiguity_data(ep) }
          episode_map[ep.id][:groups] = episode_map[ep.id][:groups].push(file.misc.group).uniq(&:id)
        end
      end

      sorted_episodes_with_groups = episode_map.values.sort_by { |eg| eg[:episode].epno }
      ranges_with_groups = []
      ranges_without_groups = []
      start_entry_with_group = sorted_episodes_with_groups.first
      start_entry_without_group = start_entry_with_group
      prev_entry = start_entry_with_group

      sorted_episodes_with_groups[1..].each do |current_entry|
        # If the episodes aren't contiguous or have different groups
        unless contiguous_with_group?(prev_entry, current_entry)
          ranges_with_groups << {
            start: start_entry_with_group[:episode],
            start_num: start_entry_with_group[:num],
            stop: prev_entry[:episode],
            stop_num: prev_entry[:num],
            **start_entry_with_group.slice(:category, :groups, :count),
          }
          start_entry_with_group = current_entry
        end

        unless contiguous?(prev_entry, current_entry)
          ranges_without_groups << {
            start: start_entry_without_group[:episode],
            start_num: start_entry_without_group[:num],
            stop: prev_entry[:episode],
            stop_num: prev_entry[:num],
            **start_entry_with_group.slice(:category, :groups, :count),
          }
          start_entry_without_group = current_entry
        end

        prev_entry = current_entry
      end

      # Add the last range.
      ranges_with_groups << {
        start: start_entry_with_group[:episode],
        start_num: start_entry_with_group[:num],
        stop: prev_entry[:episode],
        stop_num: prev_entry[:num],
        **start_entry_with_group.slice(:category, :groups, :count),
      }
      ranges_without_groups << {
        start: start_entry_without_group[:episode],
        start_num: start_entry_without_group[:num],
        stop: prev_entry[:episode],
        stop_num: prev_entry[:num],
        **start_entry_with_group.slice(:category, :groups, :count),
      }
      {
        with_groups: ranges_with_groups,
        simple: ranges_without_groups,
      }
    end

    def parts_with_groups_strings(aid, files)
      range_parts = parts_with_groups(aid, files)
      episodes_ranges = make_ranges_string(range_parts[:simple])
      episodes_ranges_with_groups = make_ranges_string(
        range_parts[:with_groups],
      ) do |range_part, range_string|
        "#{range_string} (#{range_part[:groups].map(&:short_name).join(', ')})"
      end
      {
        simple: episodes_ranges,
        with_groups: episodes_ranges_with_groups,
      }
    end
  end
end
