module Cisqua
  class RangeFormatter
    include SemanticLogger::Loggable
    def from_mylist(anime)
      from_fids(anime, MyList.fids(anime.id))
    end

    def from_fids(anime, fids)
      from_files(anime, fids.map { |fid| AnimeFile.find(fid) })
    end

    def from_files(anime, files)
      eps_by_gid = files.each_with_object({}) do |file, map|
        relevant_eps = file.episodes.select { |ep| ep.aid == anime.id }
        relevant_eps.each do |ep|
          map[file.gid] = (map[file.gid] || []) << ep
        end
      end
      eps_by_gid.transform_values! do |eps|
        eps.uniq(&:id).sort_by(&:epno)
      end

      groups = eps_by_gid.keys.map { |gid| Group.find(gid) }
      groups.sort_by! do |group|
        [
          eps_by_gid[group.id].first.epno,
          eps_by_gid[group.id].count,
        ]
      end
      groups.map do |group|
        { group: group.short_name, ep_data: from_episodes(anime, eps_by_gid[group.id]) }
      end
    end

    def from_episodes(anime, episodes)
      special, normal = episodes.partition(&:special?)
      {
        normal: from_normal_episodes(anime, normal),
        special: anime.special_ep_count.positive? ? from_special_episodes(anime, special) : nil,
      }
    end

    def from_normal_episodes(anime, episodes)
      movie_parts?(anime, episodes) ? from_movie_parts(episodes) : from_numbered_episodes(anime, episodes)
    end

    def from_numbered_episodes(anime, episodes)
      ep_nos = episodes.map(&:epno)
      epno_or_nils = (1..anime.episode_count).map do |i|
        ep_nos.find { |epno| epno.to_i == i }
      end
      chunks = epno_or_nils.chunk_while do |ep, next_ep|
        ep.nil? == next_ep.nil?
      end
      {
        category: :episode,
        range_data: chunks.select { |c| !c.first.nil? }.map do |fst, *_mid, lst|
          { ep_range: lst.nil? ? [fst] : [fst, lst] }
        end,
        bar_data: chunks.map { |c| { present: !c.first.nil?, count: c.count } },
      }
    end

    def from_special_episodes(anime, episodes)
      specials = episodes.sort_by(&:epno).map { |ep| special_info(ep) }
      chunks = specials.chunk_while do |s1, s2|
        s1[:type] == s2[:type] && s1[:number] + 1 == s2[:number]
      end
      epno_chunks = chunks.map { |c| c.map { |s| s[:epno] } }
      range_data = epno_chunks.map do |fst, *_mid, lst|
        { ep_range: lst.nil? ? [fst] : [fst, lst] }
      end
      {
        category: :special,
        range_data:,
        bar_data: { count: episodes.count, total: anime.special_ep_count },
      }
    end

    def movie_parts?(anime, episodes)
      return false if episodes.empty?

      anime.movie? && movie_part_info(episodes.first)
    end

    def from_movie_parts(episodes)
      movie_parts = episodes.map { |ep| movie_part_info(ep) }
      parts_by_total = movie_parts.group_by { |m| m[:total_parts] }.map do |total, parts|
        { total:, parts: parts.map { |p| p[:number] }.sort }
      end

      bd_raw = parts_by_total.max_by do |group|
        group[:parts].count.to_r / group[:total].to_r
      end
      bar_data_bools = (1..bd_raw[:total]).map do |i|
        bd_raw[:parts].include?(i)
      end
      bar_data_bool_chunks = bar_data_bools.chunk_while do |p1, p2|
        p1 == p2
      end
      bar_data = bar_data_bool_chunks.map { |c| { present: !c.first.nil?, count: c.count } }
      range_data = parts_by_total.map do |group|
        {
          total: group[:total],
          parts: group[:parts].chunk_while { |p, next_p| p + 1 == next_p }.map do |c|
            { part_range: c }
          end,
        }
      end
      {
        category: :movie_part,
        range_data:,
        bar_data:,
      }
    end

    def movie_part_info(episode)
      case episode.english_name
      when /Complete Movie/
        { number: 1, total_parts: 1 }
      when /Part (?<p_num>\d) of (?<p_count>\d)/
        m = Regexp.last_match
        {
          number: Integer(m[:p_num]),
          total_parts: Integer(m[:p_count]),
        }
      end
    end

    def special_info(episode)
      match = /^(?<spc_type>[A-Z])?(?<num>\d+)$/.match(episode.epno)
      {
        number: Integer(match[:num].sub(/^[0]*/, '')),
        type: match[:spc_type],
        epno: episode.epno,
      }
    end
  end
end
