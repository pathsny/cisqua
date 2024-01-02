module Cisqua
  class TestUtil
    class << self
      def prep_redis
        RedisScripts.instance.shutdown!
        FileUtils.cp(
          File.join(DATA_FOLDER, 'test_data', 'dump.rdb'),
          DATA_FOLDER,
        )
      end

      def prep_options(options_file, dry_run: false, log_level: :info)
        Registry.options_file_override = options_file
        Registry.load_options.tap do |options|
          options[:redis][:db] = 1
          options[:post_batch_actions][:plex_scan_library_files] = nil
          options[:renamer][:dry_run_mode] = dry_run
          options[:log_level] = log_level
        end
      end

      def prep_registry(options_file: nil, dry_run: false, log_level: :info, log_file_path: nil)
        options = prep_options(options_file, dry_run:, log_level:)
        Registry.test_mode_override = true
        Registry.options_override = options

        AppLogger.log_level = log_level
        AppLogger.log_file = log_file_path || File.join(DATA_FOLDER, 'test_data', 'log', 'anidb.log')
      end

      def prep(options_file: nil, dry_run: false, log_level: :info, log_file_path: nil)
        prep_registry(options_file:, dry_run:, log_level:, log_file_path:)
        RedisScripts.instance.shutdown!
      end

      def prep_for_integration_test(options_file: nil, dry_run: false, log_level: :info, log_file_path: nil)
        prep_registry(options_file:, dry_run:, log_level:, log_file_path:)
        prep_redis
      end

      def mylist_file_entries(files)
        mylist_entries = files.group_by { |file| MyList.files_key(file.aid) }
        mylist_entries.transform_values { |entry_files| entry_files.map(&:id) }
      end

      def anime_data_to_remove(episodes_to_del, other_episodes)
        anime_ep_groups = episodes_to_del.group_by { |ep| ep.anime.id }
        anime_ep_groups = anime_ep_groups.transform_keys { |id| Anime.find(id) }
        anime_ep_groups = anime_ep_groups.transform_values { |eps| eps.map(&:id) }

        anime_ep_groups_to_del, anime_ep_groups_not_to_del = anime_ep_groups.partition do |anime, eids|
          anime.episodes.all? { |ep| eids.include?(ep.id) }
        end
        animes_to_del = anime_ep_groups_to_del.to_h.keys
        associations = anime_ep_groups_not_to_del.to_h.transform_keys { |anime| "aid:#{anime.id}:episodes" }

        anime_being_kept = (
          anime_ep_groups_not_to_del.to_h.keys +
          other_episodes.map(&:anime)
        ).uniq(&:id)

        {
          keys_to_remove: {
            anime: animes_to_del.map(&:make_key_for_instance),
            association_keys: animes_to_del.map { |anime| "aid:#{anime.id}:episodes" },
          },
          sets_to_update: {
            associations:,
            mylist_entries: { 'mylist:animes': animes_to_del.map(&:id) },
          },
          sorted_sets_to_update: {
            mylist_sorted_entries: { 'mylist:sorted:animes': animes_to_del.map { |a| "#{a.romaji_name}:#{a.id}" } },
          },
          models: animes_to_del,
          models_to_update: anime_being_kept,
        }
      end

      def episode_data_to_remove(files)
        fid_set = files.to_set(&:id)

        episode_map = files.flat_map(&:episodes).uniq(&:id).to_h do |ep|
          [ep, ep.files.filter_map do |file|
                 file.id if fid_set.include?(file.id)
               end]
        end
        ep_maps_to_del, ep_maps_to_keep = episode_map.partition do |ep, fids|
          ep.files.all? do |file|
            fids.include?(file.id)
          end
        end
        eps_to_del = ep_maps_to_del.to_h.keys
        associations = ep_maps_to_keep.to_h.transform_keys { |ep| "eid:#{ep.id}:files" }
        eps_to_keep = ep_maps_to_keep.to_h.keys
        { episodes: {
          keys_to_remove: {
            episode: eps_to_del.map(&:make_key_for_instance),
            association_keys: eps_to_del.map { |ep| "eid:#{ep.id}:files" },
          },
          sets_to_update: {
            associations:,
          },
          sorted_sets_to_update: {},
          models: eps_to_del,
          models_to_update: eps_to_keep,
        } }.merge({ anime: anime_data_to_remove(eps_to_del, eps_to_keep) })
      end

      def data_to_remove_from_redis_as_if_files_never_scanned(redis, work_item_files, test_mode: true)
        searches = work_item_files.map do |w_file|
          AnimeFileSearch.find(w_file.ed2k, w_file.size_bytes)
        rescue StandardError, SolidAssert::AssertionFailedError => e
          next if w_file.name =~ /cisqua/

          raise "got error #{e} while trying to find #{w_file.name}"
        end
        unique_searches, negative_searches = searches.compact.uniq(&:make_key_for_instance).partition do |s|
          !s.fid.nil?
        end
        files = unique_searches.map(&:file)
        mylist_entries = mylist_file_entries(files)

        data_to_remove = episode_data_to_remove(files).merge(files: {
          keys_to_remove: {
            searches: unique_searches.map(&:make_key_for_instance),
            files: files.map(&:make_key_for_instance),
            miscs: files.map(&:misc).map(&:make_key_for_instance),
            negative_searches: negative_searches.map(&:make_key_for_instance),
          },
          sets_to_update: {
            mylist_entries:,
          },
          sorted_sets_to_update: {},
          models: {
            files:,
            miscs: files.map(&:misc),
            searches: unique_searches,
            negative_searches:,
          },
        })
        display_stats(data_to_remove)
        if test_mode
          assert_data(redis, data_to_remove)
        else
          remove_data(redis, data_to_remove)
        end
        change_data_source(data_to_remove)
      end

      def display_stats(data_to_remove)
        a_data = data_to_remove[:anime]
        anime_names = a_data[:models].map { |anime| "#{anime.romaji_name} (#{anime.id})" }
        ap "deleting #{anime_names.join(', ')}"
        ap a_data[:keys_to_remove]

        anime_assoc_sum = a_data[:sets_to_update][:associations].sum { |_k, eids| eids.count }
        anime_assoc_count = a_data[:sets_to_update][:associations].count

        ap "remove #{anime_assoc_count} associations totalling #{anime_assoc_sum}"
        a_sets_to_update = a_data[:sets_to_update].transform_values do |values|
          values.transform_values { |v| v.join(', ') }
        end
        a_sets_to_update.merge!(
          a_data[:sorted_sets_to_update].transform_values do |values|
            values.transform_values { |v| v.join(', ') }
          end,
        )
        ap a_sets_to_update

        e_data = data_to_remove[:episodes]
        ap "deleting #{e_data[:models].count} episodes"
        ap e_data[:keys_to_remove]

        episode_assoc_sum = e_data[:sets_to_update][:associations].sum { |_k, eids| eids.count }
        episode_assoc_count = e_data[:sets_to_update][:associations].count
        ap "remove #{episode_assoc_count} associations totalling #{episode_assoc_sum}"
        e_sets_to_update = e_data[:sets_to_update].transform_values do |values|
          values.transform_values { |v| v.join(', ') }
        end
        e_sets_to_update.merge!(
          e_data[:sorted_sets_to_update].transform_values do |values|
            values.transform_values { |v| v.join(', ') }
          end,
        )

        ap e_sets_to_update

        f_data = data_to_remove[:files]
        puts "we have to remove #{f_data[:models][:searches].count} searches"
        puts "and #{f_data[:models][:files].count} files and miscs"
        puts "and #{f_data[:models][:negative_searches].count} negative searches"
        ap(f_data[:keys_to_remove].transform_values { |keys| keys.join(', ') })
        f_sets_to_update = f_data[:sets_to_update].transform_values do |values|
          values.transform_values { |v| v.join(', ') }
        end
        ap f_sets_to_update
      end

      def assert_data(redis, data_to_remove)
        %i[anime episodes files].each do |type|
          data_to_remove[type][:keys_to_remove].each do |name, keys|
            assert(keys.all? { |k| redis.exists(k) }, "all keys exist for #{name}")
          end
          data_to_remove[type][:sets_to_update].each do |name, set_data|
            all_exist = set_data.all? { |k, members| members.all? { |mem| redis.sismember(k, mem) } }
            assert(all_exist, "all members exist for name #{name} and set #{set_data}")
          end
          data_to_remove[type][:sorted_sets_to_update].each do |name, set_data|
            all_exist = set_data.all? { |k, members| members.all? { |mem| !redis.zscore(k, mem).nil? } }
            assert(all_exist, "all members exist for name #{name} and set #{set_data}")
          end
        end
      end

      def remove_data(redis, data_to_remove)
        %i[anime episodes files].each do |type|
          data_to_remove[type][:keys_to_remove].each do |_name, keys|
            redis.del(*keys)
          end
          data_to_remove[type][:sets_to_update].each do |_name, set_data|
            set_data.each do |s_key, s_values|
              redis.srem(s_key, *s_values)
            rescue StandardError => e
              puts "I see #{e} while removing #{set_data}"
              raise
            end
          end
          data_to_remove[type][:sorted_sets_to_update].each do |_name, set_data|
            set_data.each do |s_key, s_values|
              redis.zrem(s_key, s_values)
            rescue StandardError => e
              puts "I see #{e} while removing #{set_data}"
              raise
            end
          end
        end
      end

      def change_data_source(data_to_remove)
        %i[anime episodes files].each do |type|
          next unless data_to_remove[type].key?(:models_to_update)

          data_to_remove[type][:models_to_update].each do |model|
            model.data_source = 'mylist-import'
            model.updated_at = Time.at(1_691_564_400)
            model.save
          end
        end
      end

      def remove_episode_files_from_redis_as_if_never_scanned(redis, eid)
        # deletes all files for an episode as if it was never scanned
        episode = Episode.find(eid)
        files = episode.files

        files.each do |file|
          redis.srem(MyList.files_key(file.aid), file.id)
          redis.del(file.misc.make_key_for_instance)
          redis.del(file.make_key_for_instance)
          file.episodes.each do |ep|
            redis.srem("eid:#{ep.id}:files", file.id)
          end
        end
      end
    end
  end
end
