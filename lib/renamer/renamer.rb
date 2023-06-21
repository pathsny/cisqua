require_relative '../../rename_rules'
require 'fileutils'
require 'pathname'
require 'invariant'
require 'rest_client'

module Renamer
  class Renamer
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
        response = @mover.process(work_item.file, unknown_location,
                                  { unambiguous: true, **override_options })
        assert(response.type == :success, 'moving unknown files should not fail')
        return Response.unknown(response.destination)
      end

      location, path, name = generate_location(work_item.info)
      process_file(name, work_item, location, path, override_options)
    rescue StandardError
      Loggers::Renamer.error "error naming #{work_item.file} from #{work_item.info.inspect} with #{$!}"
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

      unless result[:keep_current]
        junk_duplicate_location = File.absolute_path(options[:junk_duplicate_location], ROOT_FOLDER)
        fix_symlinks_root = File.absolute_path(options[:fix_symlinks_root], ROOT_FOLDER)
        resp = @mover.process(existing.file, junk_duplicate_location,
                              new_name: name,
                              unambiguous: true,
                              symlink_source: false,
                              update_links_from: fix_symlinks_root)
        assert(resp.type == :success, 'moving the existing file should not fail')
        process_file(name, result[:selected], location, path).tap do |r|
          assert(r.type == :success, 'we just cleared the location')
        end
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
      @mover.process(work_item.file, junk_duplicate_location,
                     new_name: name,
                     unambiguous: true)
    end

    def move_to_dup(name, work_item)
      duplicate_location = File.absolute_path(options[:duplicate_location], ROOT_FOLDER)
      @mover.process(work_item.file, duplicate_location,
                     new_name: name,
                     unambiguous: true)
    end

    def process_file(name, work_item, location, path, override_options = {})
      @mover.process(work_item.file, location, { new_name: name, **override_options }).tap do |response|
        if response.type == :success
          @atleast_one_success = true
          ensure_nfo(location, work_item.info)
          ensure_anidb_id_file(location, work_item.info)
          update_symlinks_for(work_item.info[:anime], path, location) if options[:create_symlinks]
        end
      end
    end

    def generate_location(info)
      path, name = @name_generator.generate_name_and_path(info)
      [File.join(@output_location, path), path, name]
    end

    def ensure_nfo(location, info)
      nfo_path = File.join(location, 'tvshow.nfo')
      return if File.exist?(nfo_path) || !options[:create_nfo_files]

      Loggers::Renamer.debug("Creating #{nfo_path}. #{@options[:dry_run_mode] ? ' DRY RUN' : ''}")
      File.open(nfo_path, 'w') { |f| f.write("aid=#{info[:file][:aid]}") } unless options[:dry_run_mode]
    end

    def ensure_anidb_id_file(location, info)
      idfile_path = File.join(location, 'anidb.id')
      return if File.exist?(idfile_path) || !options[:create_anidb_id_files]

      Loggers::Renamer.debug("Creating #{idfile_path}. #{@options[:dry_run_mode] ? ' DRY RUN' : ''}")
      File.open(idfile_path, 'w') { |f| f.write("#{info[:file][:aid]}\n") } unless options[:dry_run_mode]
    end

    def update_symlinks_for(ainfo, folder, location)
      symlink_types = %i[movies incomplete_series complete_series
                         incomplete_other complete_other adult_location]
      all_locations = symlink_types.map do |k|
        File.absolute_path(options[:create_symlinks][k], ROOT_FOLDER)
      end.compact
      correct_location = decide_symlink_location(ainfo)
      incorrect_locations = all_locations.reject { |a| a == correct_location }
      incorrect_locations.each do |l|
        s = File.join(l, folder)
        if File.symlink?(s)
          File.unlink(s) unless options[:dry_run_mode]
          Loggers::Renamer.info "DELETING symlink #{'DRY RUN' if options[:dry_run_mode]}\n\t#{s}  <--X\n\t#{location}"
        end
      end
      if correct_location && !File.symlink?("#{correct_location}/#{folder}")
        symlink(location, correct_location, folder)
        Loggers::Renamer.info "SYMLINKING \n\t#{location} <---\n\t#{correct_location}/#{folder}"
      end
    end

    def decide_symlink_location(ainfo)
      symlink_locations = options[:create_symlinks]
      return File.absolute_path(symlink_locations[:adult_location], ROOT_FOLDER) if ainfo[:is_18_restricted] == '1'
      return File.absolute_path(symlink_locations[:movies], ROOT_FOLDER) if ainfo[:type] == 'Movie'

      type = ['Web', 'TV Series', 'OVA', 'TV Special'].include?(ainfo[:type]) ? :series : :other
      status = ainfo[:ended] && ainfo[:completed] ? :complete : :incomplete
      File.absolute_path(symlink_locations["#{status}_#{type}".to_sym], ROOT_FOLDER)
    end

    def symlink(source, dest, name)
      @symlinker.relative_with_name(source, dest, name)
    rescue StandardError => e
      Loggers::Renamer.warn e.inspect
      raise
    end

    def plex_scan_library_files(plex_opt)
      return unless plex_opt

      uri = URI::HTTP.build(
        host: plex_opt[:host],
        port: plex_opt[:port],
        path: "/library/sections/#{plex_opt[:section]}/refresh"
      ).to_s
      Loggers::Renamer.debug "updating plex at #{uri}"
      resp = RestClient.get(uri, params: { 'X-Plex-Token': plex_opt[:token] })
      if resp.code == 200
        Loggers::Renamer.info "Requested plex server at #{uri} to scan library files"
      else
        Loggers::Renamer.error "could not update plex. Got status code #{resp.code} and body #{resp.body}"
      end
    end
  end
end
