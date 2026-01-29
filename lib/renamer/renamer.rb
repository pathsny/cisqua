require 'English'
require 'fileutils'
require 'pathname'

module Cisqua
  module Renamer
    class Renamer
      include SemanticLogger::Loggable

      def initialize(options, api_client)
        @options = options
        @output_location = File.absolute_path(options[:output_location], ROOT_FOLDER)
        @api_client = api_client
        @mover = VideoFileMover.new(options)
        @symlinker = Symlinker.new(options)
      end

      attr_reader :options

      def process(work_item)
        case work_item.request_type
        when :standard
          process_standard(work_item)
        when :duplicate_set
          process_duplicate_set(work_item)
        else
          assert(false, "unknown request type #{work_item.request_type}")
        end
      end

      def process_standard(work_item)
        unless work_item.file
          unknown_location = File.absolute_path(options[:unknown_location], ROOT_FOLDER)
          response = @mover.process(
            src_file: work_item.source.path,
            dst_dir: unknown_location,
            unambiguous: true,
            symlink_source: options[:symlink_source],
          )
          assert(response.type == :success, 'moving unknown files should not fail')
          return Response.unknown(response.destination)
        end

        move_data = generate_location(work_item.file)
        process_file(
          work_item.file,
          src_file: work_item.source.path,
          symlink_source: options[:symlink_source],
          **move_data,
        )
      rescue StandardError
        logger.error(
          'error while renaming',
          source: work_item.source.path,
          fid: work_item.file&.id,
          exception: $ERROR_INFO,
        )
        raise
      end

      def process_name_change(anime)
        new_dir_name = NameGenerator.generate_dir_name_for_anime(anime)
        old_dir_name = NameGenerator.generate_old_dir_name_for_anime(anime)
        logger.info('post process name change', old_dir_name:, new_dir_name:)
        assert(new_dir_name != old_dir_name, 'directory name should change')

        src_dir = File.join(@output_location, old_dir_name)
        result = @mover.move_directory_contents(
          src_dir:,
          dst_dir: File.join(@output_location, new_dir_name),
          src_file_prefix: old_dir_name,
          dst_file_prefix: new_dir_name,
          update_links_from: fix_symlinks_root,
        )

        return unless result

        # we successfully moved the directory contents. Now we have to update
        # symlinks.
        update_symlinks_for(
          anime,
          dst_dir_name: new_dir_name,
          dst_dir: File.join(@output_location, new_dir_name),
          old_dst_dir_name: old_dir_name,
        )
        FileUtils.rmdir(src_dir)
      end

      private

      # given a work_item indicating the existing file and given
      # a list of duplicates, processes all of them
      def process_duplicate_set(work_item)
        existing = work_item
        duplicates = work_item.duplicate_work_items

        result = DuplicateResolver.resolve(existing, duplicates)
        # get data shared by all files
        move_data = generate_location(existing.file)
        duplicate_location, junk_duplicate_location = %i[duplicate_location junk_duplicate_location].map do |type|
          File.absolute_path(options[type], ROOT_FOLDER)
        end
        { junk: junk_duplicate_location, dups: duplicate_location }.each do |k, location|
          result[k].each do |item|
            @mover.process(
              **move_data.slice(:new_name),
              src_file: item.source.path,
              dst_dir: location,
              unambiguous: true,
              symlink_source: options[:symlink_source],
            )
          end
        end

        if result[:keep_current]
          return Response.unchanged(
            existing.source.path,
            **result.slice(:junk, :dups),
          )
        end

        clear_location_resp = @mover.process(
          src_file: existing.source.path,
          **move_data,
          dst_dir: junk_duplicate_location,
          unambiguous: true,
          symlink_source: false,
          update_links_from: fix_symlinks_root,
        )
        assert(clear_location_resp.type == :success, 'moving the existing file should not fail')
        @api_client.remove_from_mylist(existing.file.id)

        replacement_resp = process_file(
          result[:selected].file,
          src_file: result[:selected].source.path,
          symlink_source: options[:symlink_source],
          **move_data,
        )
        assert(replacement_resp.type == :success, 'we just cleared the location')
        reason = existing[:quality].compare_with_info(
          result[:selected][:quality],
        ).slice(:left, :right)
        Response.replaced(
          replacement_resp.destination,
          dups: result[:dups],
          junk: result[:junk],
          replacement: {
            new_item: result[:selected],
            old_item: existing,
            reason: reason.transform_keys { |k| { left: :old, right: :new }[k] },
          },
        )
      end

      def fix_symlinks_root
        File.absolute_path(options[:fix_symlinks_root], ROOT_FOLDER)
      end

      def process_file(anime_file, dst_dir:, **move_data)
        response = @mover.process(dst_dir:, **move_data) do |is_duplicate|
          unless is_duplicate
            # we're about to move the file. Lets add it to mylist
            @api_client.add_to_mylist(anime_file)
          end
        end
        response.tap do |r|
          if r.type == :success
            update_symlinks_for(
              anime_file.anime,
              dst_dir:,
              old_dst_dir_name: move_data[:dst_dir_name],
              **move_data,
            )
            ensure_anidb_id_file(dst_dir, anime_file)
          end
        end
      end

      def generate_location(anime_file)
        dst_dir_name = NameGenerator.generate_dir_name_for_file(anime_file)
        {
          new_name: NameGenerator.generate_name(anime_file),
          dst_dir_name:,
          dst_dir: File.join(@output_location, dst_dir_name),
        }
      end

      def ensure_anidb_id_file(dst_dir, anime_file)
        idfile_path = File.join(dst_dir, 'anidb.id')
        return if File.exist?(idfile_path) || !options[:create_anidb_id_files]

        logger.debug(
          'Creating File',
          name: idfile_path,
          DRY_RUN: @options[:dry_run_mode],
        )
        File.write(idfile_path, "#{anime_file.aid}\n") unless options[:dry_run_mode]
      end

      def update_symlinks_for(anime, dst_dir_name:, old_dst_dir_name:, dst_dir:, **)
        symlink_types = %i[movies incomplete_series complete_series
                           incomplete_other complete_other adult_location]
        all_locations = symlink_types.map do |k|
          File.absolute_path(options[:create_symlinks][k], ROOT_FOLDER)
        end.compact
        correct_location = decide_symlink_location(anime)

        locations_with_incorrect_symlinks = all_locations
        if dst_dir_name == old_dst_dir_name
          # since the directory name didnt change, the correct location symlink
          # is correct.
          locations_with_incorrect_symlinks = all_locations.reject do |a|
            a == correct_location
          end
        end
        locations_with_incorrect_symlinks.each do |l|
          s = File.join(l, old_dst_dir_name)
          next unless File.symlink?(s)

          logger.info(
            'DELETING symlink',
            DRY_RUN: options[:dry_run_mode],
            symlink: s,
            target: File.readlink(s),
          )
          File.unlink(s) unless options[:dry_run_mode]
        end
        return if File.symlink?("#{correct_location}/#{dst_dir_name}")

        symlink(dst_dir, correct_location, dst_dir_name)
        logger.info(
          'SYMLINKING',
          to: dst_dir,
          from: "#{correct_location}/#{dst_dir_name}",
        )
      end

      def decide_symlink_location(anime)
        symlink_locations = options[:create_symlinks]
        return File.absolute_path(symlink_locations[:adult_location], ROOT_FOLDER) if anime.is_18_restricted
        return File.absolute_path(symlink_locations[:movies], ROOT_FOLDER) if anime.movie?

        type = ['Web', 'TV Series', 'OVA', 'TV Special'].include?(anime.type) ? :series : :other
        mylist_status = MyList.instance.entries[anime.id].complete? ? :complete : :incomplete
        File.absolute_path(symlink_locations[:"#{mylist_status}_#{type}"], ROOT_FOLDER)
      end

      def symlink(source, dest, name)
        @symlinker.relative_with_name(source, dest, name)
      rescue StandardError => e
        logger.warn('error during symlink', exception: e)
        raise
      end
    end
  end
end
