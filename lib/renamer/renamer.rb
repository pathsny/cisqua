require 'English'
require 'fileutils'
require 'pathname'
require 'invariant'
require 'rest_client'

module Cisqua
  require File.join(ROOT_FOLDER, 'rename_rules')

  module Renamer
    class Renamer
      include SemanticLogger::Loggable

      def initialize(options)
        @options = options
        @output_location = File.absolute_path(options[:output_location], ROOT_FOLDER)
        @mover = VideoFileMover.new(options)
        @symlinker = Symlinker.new(options)
        @name_generator = NameGenerator.new(method(:generate_name))
        @atleast_one_success = false
      end

      attr_reader :options

      def try_process(work_item, override_options = {})
        unless work_item.info
          unknown_location = File.absolute_path(options[:unknown_location], ROOT_FOLDER)
          response = @mover.process(
            work_item.file.name,
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
          source: work_item.file.name,
          data: work_item.info,
          exception: $ERROR_INFO,
        )
        raise
      end

      # given a work_item indicating the existing file and given
      # a list of duplicates, processes all of them
      def process_duplicate_set(existing, duplicates)
        result = DuplicateResolver.resolve(existing, duplicates)
        # get data shared by all files
        location, path, name = generate_location(existing[:info])
        junk = curried_method(:move_to_junk)[name]
        dup = curried_method(:move_to_dup)[name]
        result[:junk].each(&junk)
        result[:dups].each(&dup)
        return if result[:keep_current]

        junk_duplicate_location = File.absolute_path(options[:junk_duplicate_location], ROOT_FOLDER)
        fix_symlinks_root = File.absolute_path(options[:fix_symlinks_root], ROOT_FOLDER)
        resp = @mover.process(
          existing.file.name,
          junk_duplicate_location,
          new_name: name,
          unambiguous: true,
          symlink_source: false,
          update_links_from: fix_symlinks_root,
        )
        assert(resp.type == :success, 'moving the existing file should not fail')
        process_file(name, result[:selected], location, path).tap do |r|
          assert(r.type == :success, 'we just cleared the location')
        end
      end

      def post_rename_actions
        plex_scan_library_files(options[:plex_scan_library_files]) if @atleast_one_success
      end

      private

      def curried_method(sym)
        proc(&method(sym)).curry
      end

      def move_to_junk(name, work_item)
        junk_duplicate_location = File.absolute_path(options[:junk_duplicate_location], ROOT_FOLDER)
        @mover.process(
          work_item.file.name,
          junk_duplicate_location,
          new_name: name,
          unambiguous: true,
        )
      end

      def move_to_dup(name, work_item)
        duplicate_location = File.absolute_path(options[:duplicate_location], ROOT_FOLDER)
        @mover.process(
          work_item.file.name,
          duplicate_location,
          new_name: name,
          unambiguous: true,
        )
      end

      def process_file(name, work_item, location, path, override_options = {})
        @mover.process(
          work_item.file.name,
          location,
          { new_name: name, **override_options },
        ).tap do |response|
          if response.type == :success
            @atleast_one_success = true
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
        File.absolute_path(symlink_locations["#{mylist_status}_#{type}".to_sym], ROOT_FOLDER)
      end

      def symlink(source, dest, name)
        @symlinker.relative_with_name(source, dest, name)
      rescue StandardError => e
        logger.warn('error during symlink', exception: e)
        raise
      end

      def plex_scan_library_files(plex_opt)
        return unless plex_opt

        uri = URI::HTTP.build(
          host: plex_opt[:host],
          port: plex_opt[:port],
          path: "/library/sections/#{plex_opt[:section]}/refresh",
        ).to_s
        logger.debug(
          'updating plex',
          plex_server: uri,
        )
        begin
          resp = RestClient.get(uri, params: { 'X-Plex-Token': plex_opt[:token] })
          if resp.code == 200
            logger.info(
              'Requested plex server to scan library files',
              plex_server: uri,
            )
          else
            logger.error(
              'could not update plex',
              plex_server: uri,
              code: resp.code,
              body: resp.body,
            )
          end
        rescue StandardError => e
          logger.error(
            'could not update plex',
            plex_server: uri,
            exception: e,
            log_exception: :full,
          )
        end
      end
    end
  end
end
