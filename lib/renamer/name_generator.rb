# this method should return a path where files should be stored inside the destination directory and
# the name that an identified file should take.
# As a sample, the given file uses the romanji name of the anime as the folder
# and the file is written as anime_name - episode <number> [groupname] and movie files are stored as
# anime_name - Complete Movie or anime_name - Part 1 of 3.
# here is a sample of the "info" you will get if you want to change the name format.

# {
#   fid: 271_926,
#   file: {
#     length: '1778',
#     quality: 'high',
#     video_resolution: '640x480',
#     source: 'LD',
#     sub_language: 'none',
#     gid: '0',
#     dub_language: 'japanese',
#     eid: '26772',
#     aid: '1179',
#   },
#   anime: {
#     type: 'OVA',
#     ep_romaji_name: '',
#     highest_episode_number: '2',
#     group_name: 'raw/unknown',
#     english_name: '',
#     group_short_name: 'raw',
#     romaji_name: 'Bounty Dog: Getsumen no Ibu',
#     year: '1994-1994', epno: '1',
#     ep_english_name: 'Code 1'
#   },
# }
module Cisqua
  module Renamer
    class NameGenerator
      class << self
        def generate_dir_name_for_file(file)
          escape(file.anime.romaji_name)
        end

        def generate_dir_name_for_anime(anime)
          escape(anime.romaji_name)
        end

        def generate_old_dir_name_for_anime(anime)
          escape(anime.romaji_name_previously_was)
        end

        def generate_name(file)
          escape(generate_name_impl(file))
        end

        protected

        def generate_name_impl(file)
          misc = file.misc
          name = file.anime.romaji_name
          episode = " - episode #{misc.epno}"
          part = if file.anime.movie?
            if /Complete Movie|Part \d of \d/.match(misc.ep_english_name) && !misc.special?
              " - #{misc.ep_english_name}"
            else
              "#{episode} - #{misc.ep_english_name}"
            end
          else
            episode
          end
          "#{name}#{part}#{group_name(misc)}"
        end

        def group_name(misc)
          g = misc.group_short_name
          g == 'raw' ? nil : " [#{g}]"
        end

        def escape(name)
          valid_chars = %w(\w \. \- \[ \] \( \) &).join
          invalid_rg = "[^#{valid_chars}\s]"
          name.gsub(Regexp.new("#{invalid_rg}(?![#{valid_chars}])"), '')
            .gsub(Regexp.new("\\s#{invalid_rg}"), ' ')
            .gsub(Regexp.new(invalid_rg), ' ')
            .strip.squeeze(' ')
            .sub(/\.$/, '')
        end
      end
    end
  end
end
