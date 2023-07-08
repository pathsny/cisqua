module Net
  FILE_AMASKS = {
    :anime_total_episodes    => 0x80000000,
    :highest_episode_number  => 0x40000000,
    :year                    => 0x20000000,
    :type                    => 0x10000000,
    :related_aid_list        => 0x08000000,
    :related_aid_type        => 0x04000000,
    :category_list           => 0x02000000,
    #reserved                => 0x01000000,
    :romaji_name             => 0x00800000,
    :kanji_name              => 0x00400000,
    :english_name            => 0x00200000,
    :other_name              => 0x00100000,
    :short_name_list         => 0x00080000,
    :synonym_list            => 0x00040000,
    #retired                 => 0x00020000,
    #retired                 => 0x00010000,
    :epno                    => 0x00008000,
    :ep_english_name         => 0x00004000,
    :ep_romaji_name          => 0x00002000,
    :ep_kanji_name           => 0x00001000,
    :ep_rating               => 0x00000800,
    :ep_vote_count           => 0x00000400,
    #unused                  => 0x00000200,
    #unused                  => 0x00000100,
    :group_name              => 0x00000080,
    :group_short_name        => 0x00000040,
    #unused                  => 0x00000020,
    #unused                  => 0x00000010,
    #unused                  => 0x00000008,
    #unused                  => 0x00000004,
    #unused                  => 0x00000002,
    :date_aid_record_updated => 0x00000001,
  }

  FILE_AMASKS_ORDER = [
    :anime_total_episodes, :highest_episode_number, :year, :type, :related_aid_list, :related_aid_type, :category_list, 
    :romaji_name, :kanji_name, :english_name, :other_name, :short_name_list, :synonym_list, 
    :epno, :ep_english_name, :ep_romaji_name, :ep_kanji_name, :ep_rating, :ep_vote_count, 
    :group_name, :group_short_name, :date_aid_record_updated, 
  ]

  FILE_FMASKS = {
    #unused             => 0x80000000,
    :aid                => 0x40000000,
    :eid                => 0x20000000,
    :gid                => 0x10000000,
    :mylist_id          => 0x08000000,
    :other_episodes     => 0x04000000,
    :is_deprecated      => 0x02000000,
    :state              => 0x01000000,
    :size               => 0x00800000,
    :ed2k               => 0x00400000,
    :md5                => 0x00200000,
    :sha1               => 0x00100000,
    :crc32              => 0x00080000,
    #unused             => 0x00040000,
    #unused             => 0x00020000,
    #reserved           => 0x00010000,
    :quality            => 0x00008000,
    :source             => 0x00004000,
    :audio_codec_list   => 0x00002000,
    :audio_bitrate_list => 0x00001000,
    :video_codec        => 0x00000800,
    :video_bitrate      => 0x00000400,
    :video_resolution   => 0x00000200,
    :file_type          => 0x00000100,
    :dub_language       => 0x00000080,
    :sub_language       => 0x00000040,
    :length             => 0x00000020,
    :description        => 0x00000010,
    :aired_date         => 0x00000008,
    #unused             => 0x00000004,
    #unused             => 0x00000002,
    :anidb_file_name    => 0x00000001,
  }

  FILE_FMASKS_ORDER = [
    :aid, :eid, :gid, :mylist_id, :other_episodes, :is_deprecated, :state, 
    :size, :ed2k, :md5, :sha1, :crc32, 
    :quality, :source, :audio_codec_list, :audio_bitrate_list, :video_codec, :video_bitrate, :video_resolution, :file_type, 
    :dub_language, :sub_language, :length, :description, :aired_date, :anidb_file_name, 
  ]

  FILE_STATE_MASKS = {
    :crc_ok => 0x01,
    :crc_err => 0x02,
    :file_v2 => 0x04,
    :file_v3 => 0x08,
    :file_v4 => 0x10,
    :file_v5 => 0x20,
    :uncensored => 0x40,
    :censored => 0x80
  }

  CRC_STATES = {
    :name => :crc_status,
    :default => :crc_unchecked, 
    :keys => [:crc_ok, :crc_err]
  }
  
  CENSORED_STATES = {
    :name => :censored,
    :default => :unknown,
    :keys => [:uncensored, :censored]
  }

  VERSION_STATES = {
    :name => :version,
    :default => :file_v1,
    :keys => [:file_v2, :file_v3, :file_v4, :file_v5],
    :map => {
      :file_v1 => 1,
      :file_v2 => 2,
      :file_v3 => 3,
      :file_v4 => 4,
      :file_v5 => 5
    }
  }

  STATE_PARTS = [CRC_STATES, CENSORED_STATES, VERSION_STATES]

  ANIME_AMASKS = {
    :aid                    => 0x80000000000000,
    :dateflags             => 0x40000000000000,
    :year                   => 0x20000000000000,
    :type                   => 0x10000000000000,
    :related_aid_list       => 0x08000000000000,
    :related_aid_type       => 0x04000000000000,
    :category_list          => 0x02000000000000,
    :category_weight_list   => 0x01000000000000,
    :romaji_name            => 0x00800000000000,
    :kanji_name             => 0x00400000000000,
    :english_name           => 0x00200000000000,
    :other_name             => 0x00100000000000,
    :short_name_list        => 0x00080000000000,
    :synonym_list           => 0x00040000000000,
    #retired                => 0x00020000000000,
    #retired                => 0x00010000000000,
    :episodes               => 0x00008000000000,
    :highest_episode_number => 0x00004000000000,
    :special_ep_count       => 0x00002000000000,
    :air_date               => 0x00001000000000,
    :end_date               => 0x00000800000000,
    :url                    => 0x00000400000000,
    :picname                => 0x00000200000000,
    :category_id_list       => 0x00000100000000,
    :rating                 => 0x00000080000000,
    :vote_count             => 0x00000040000000,
    :temp_rating            => 0x00000020000000,
    :temp_vote_count        => 0x00000010000000,
    :average_review_rating  => 0x00000008000000,
    :review_count           => 0x00000004000000,
    :award_list             => 0x00000002000000,
    :is_18_restricted       => 0x00000001000000,
    :anime_planet_id        => 0x00000000800000,
    :ANN_id                 => 0x00000000400000,
    :allcinema_id           => 0x00000000200000,
    :AnimeNfo_id            => 0x00000000100000,
    #unused                 => 0x00000000080000,
    #unused                 => 0x00000000040000,
    #unused                 => 0x00000000020000,
    :date_record_updated    => 0x00000000010000,
    :character_id_list      => 0x00000000008000,
    :creator_id_list        => 0x00000000004000,
    :main_creator_id_list   => 0x00000000002000,
    :main_creator_name_list => 0x00000000001000,
    #unused                 => 0x00000000000800,
    #unused                 => 0x00000000000400,
    #unused                 => 0x00000000000200,
    #unused                 => 0x00000000000100,
    :specials_count         => 0x00000000000080,
    :credits_count          => 0x00000000000040,
    :other_count            => 0x00000000000020,
    :trailer_count          => 0x00000000000010,
    :parody_count           => 0x00000000000008,
    #unused                 => 0x00000000000004,
    #unused                 => 0x00000000000002,
    #unused                 => 0x00000000000001,
  }

  ANIME_AMASKS_ORDER = [
    :aid, :dateflags, :year, :type, :related_aid_list, :related_aid_type, :category_list, :category_weight_list, 
    :romaji_name, :kanji_name, :english_name, :other_name, :short_name_list, :synonym_list, 
    :episodes, :highest_episode_number, :special_ep_count, :air_date, :end_date, :url, :picname, :category_id_list, 
    :rating, :vote_count, :temp_rating, :temp_vote_count, :average_review_rating, :review_count, :award_list, :is_18_restricted, 
    :anime_planet_id, :ANN_id, :allcinema_id, :AnimeNfo_id, :date_record_updated, 
    :character_id_list, :creator_id_list, :main_creator_id_list, :main_creator_name_list, 
    :specials_count, :credits_count, :other_count, :trailer_count, :parody_count, 
  ]
end