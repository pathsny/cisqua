require 'English'
require 'fileutils'
require 'pathname'

module Cisqua
  require File.join(ROOT_FOLDER, 'rename_rules')

  module Renamer
    class Renamer
      include SemanticLogger::Loggable

      def initialize(options, api_client)
        @options = options
        @output_location = File.absolute_path(options[:output_location], ROOT_FOLDER)
        @api_client = api_client
        @mover = VideoFileMover.new(options)
        @symlinker = Symlinker.new(options)
        @name_generator = NameGenerator.new(method(:generate_name))
      end

      attr_reader :options

      def process(work_item, override_options = {})
        case work_item.request_type
        when :standard
          process_standard(work_item, override_options)
        when :duplicate_set
          process_duplicate_set(work_item, override_options)
        else
          assert(false, "unknown request type #{work_item.request_type}")
        end
      end

      def process_standard(work_item, override_options)
        unless work_item.info
          unknown_location = File.absolute_path(options[:unknown_location], ROOT_FOLDER)
          response = @mover.process(
            work_item.file.path,
            unknown_location,
            { unambiguous: true, **override_options },
          )
          assert(response.type == :success, 'moving unknown files should not fail')
          return Response.unknown(response.destination)
        end

        location, path, name = generate_location(work_item.info)
        process_file(name, work_item, location, path, override_options)
      rescue StandardError
        logger.error(
          'error while renaming',
          source: work_item.file.path,
          data: work_item.info,
          exception: $ERROR_INFO,
        )
        raise
      end

      # given a work_item indicating the existing file and given
      # a list of duplicates, processes all of them
      def process_duplicate_set(work_item, _override_options)
        existing = work_item
        duplicates = work_item.duplicate_work_items
        result = DuplicateResolver.resolve(existing, duplicates)
        # get data shared by all files
        location, path, name = generate_location(existing[:info])
        junk = curried_method(:move_to_junk)[name]
        dup = curried_method(:move_to_dup)[name]
        result[:junk].each(&junk)
        result[:dups].each(&dup)
        return Response.unchanged(existing.file.path) if result[:keep_current]

        junk_duplicate_location = File.absolute_path(options[:junk_duplicate_location], ROOT_FOLDER)
        fix_symlinks_root = File.absolute_path(options[:fix_symlinks_root], ROOT_FOLDER)
        clear_location_resp = @mover.process(
          existing.file.path,
          junk_duplicate_location,
          new_name: name,
          unambiguous: true,
          symlink_source: false,
          update_links_from: fix_symlinks_root,
        )
        assert(clear_location_resp.type == :success, 'moving the existing file should not fail')
        @api_client.remove_from_mylist(existing.info[:fid])

        replacement_resp = process_file(name, result[:selected], location, path)
        assert(replacement_resp.type == :success, 'we just cleared the location')
        Response.replaced(result[:selected], replacement_resp.destination)
      end

      private

      def curried_method(sym)
        proc(&method(sym)).curry
      end

      def move_to_junk(name, work_item)
        junk_duplicate_location = File.absolute_path(options[:junk_duplicate_location], ROOT_FOLDER)
        @mover.process(
          work_item.file.path,
          junk_duplicate_location,
          new_name: name,
          unambiguous: true,
        )
      end

      def move_to_dup(name, work_item)
        duplicate_location = File.absolute_path(options[:duplicate_location], ROOT_FOLDER)
        @mover.process(
          work_item.file.path,
          duplicate_location,
          new_name: name,
          unambiguous: true,
        )
      end

      def process_file(name, work_item, location, path, override_options = {})
        @mover.process(
          work_item.file.path,
          location,
          { new_name: name, **override_options },
        ).tap do |response|
          if response.type == :success
            @api_client.add_to_mylist(work_item.info[:fid])
            ensure_anidb_id_file(location, work_item.info)
            update_symlinks_for(work_item, path, location) if options[:create_symlinks]
          end
        end
      end

      def generate_location(info)
        path, name = @name_generator.generate_name_and_path(info)
        [File.join(@output_location, path), path, name]
      end

      def ensure_anidb_id_file(location, info)
        idfile_path = File.join(location, 'anidb.id')
        return if File.exist?(idfile_path) || !options[:create_anidb_id_files]

        logger.debug(
          'Creating File',
          name: idfile_path,
          DRY_RUN: @options[:dry_run_mode],
        )
        File.write(idfile_path, "#{info[:file][:aid]}\n") unless options[:dry_run_mode]
      end

      def update_symlinks_for(work_item, folder, location)
        symlink_types = %i[movies incomplete_series complete_series
                           incomplete_other complete_other adult_location]
        all_locations = symlink_types.map do |k|
          File.absolute_path(options[:create_symlinks][k], ROOT_FOLDER)
        end.compact
        correct_location = decide_symlink_location(work_item)
        incorrect_locations = all_locations.reject { |a| a == correct_location }
        incorrect_locations.each do |l|
          s = File.join(l, folder)
          next unless File.symlink?(s)

          logger.info(
            'DELETING symlink',
            DRY_RUN: options[:dry_run_mode],
            symlink: s,
            target: File.readlink(s),
          )
          File.unlink(s) unless options[:dry_run_mode]
        end
        return if File.symlink?("#{correct_location}/#{folder}")

        symlink(location, correct_location, folder)
        logger.info(
          'SYMLINKING',
          to: location,
          from: "#{correct_location}/#{folder}",
        )
      end

      def decide_symlink_location(work_item)
        ainfo = work_item.info[:anime]
        symlink_locations = options[:create_symlinks]
        return File.absolute_path(symlink_locations[:adult_location], ROOT_FOLDER) if ainfo[:is_18_restricted] == '1'
        return File.absolute_path(symlink_locations[:movies], ROOT_FOLDER) if ainfo[:type] == 'Movie'

        type = ['Web', 'TV Series', 'OVA', 'TV Special'].include?(ainfo[:type]) ? :series : :other
        mylist_status = MyList.complete?(work_item.info[:file][:aid]) ? :complete : :incomplete
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
