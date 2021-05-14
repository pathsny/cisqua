require_relative '../../rename_rules'
require 'fileutils'
require 'pathname'
require 'invariant'
require 'rest_client'

module Renamer
  class Renamer
    def initialize(options)
      @options = options
      @mover = VideoFileMover.new(options)
      @name_generator = NameGenerator.new(method(:generate_name))
      @atleast_one_success = false
    end

    attr_reader :options

    def try_process(work_item)
      unless work_item.info
        response = @mover.process(work_item.file, options[:unknown_location],
          :unambiguous => true
        ) if options[:unknown_location]
        assert(response.type == :success, "moving unknown files should not fail")
        return Response.unknown(response.destination)
      end

      location, path, name = generate_location(work_item.info)
      process_file(name, work_item, location, path)
    rescue
      Loggers::Renamer.error "error naming #{work_item.file} from #{work_item.info.inspect} with #{$!}"
      raise
    end

    # given a work_item indicating the existing file and given
    # a list of duplicates, processes all of them
    def process_duplicate_set(existing, duplicates)
      result = DuplicateResolver.resolve(existing, duplicates)
      #get data shared by all files
      location, path, name = generate_location(existing[:info])
      junk = curried_method(:move_to_junk)[name]
      dup = curried_method(:move_to_dup)[name]
      result[:junk].each(&junk)
      result[:dups].each(&dup)

      if !result[:keep_current]
        resp = @mover.process(existing.file, options[:junk_duplicate_location],
          :new_name => name,
          :unambiguous => true,
          :symlink_source => false,
          :update_links_from => options[:fix_symlinks_root]
        )
        assert(resp.type == :success, "moving the existing file should not fail")
        process_file(name, result[:selected], location, path).tap {|r|
          assert(r.type == :success, "we just cleared the location")
        }
      end
    end

    def post_rename_actions
      if (@atleast_one_success)
        plex_scan_library_files(options[:plex_scan_library_files])
      end
    end

    private
    def curried_method(sym)
      proc(&method(sym)).curry
    end

    def move_to_junk(name, work_item)
      @mover.process(work_item.file, options[:junk_duplicate_location],
        :new_name => name,
        :unambiguous => true
      )
    end

    def move_to_dup(name, work_item)
      @mover.process(work_item.file, options[:duplicate_location],
        :new_name => name,
        :unambiguous => true
      )
    end

    def process_file(name, work_item, location, path)
      @mover.process(work_item.file, location, :new_name => name).tap do |response|
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
      [File.join(options[:output_location], path), path, name]
    end

    def ensure_nfo(location, info)
      nfo_path = File.join(location, 'tvshow.nfo')
      File.open(nfo_path, 'w') do |f|
        f.write("aid=#{info[:file][:aid]}")
      end if !File.exist?(nfo_path) && options[:create_nfo_files]
    end

    def ensure_anidb_id_file(location, info)
      idfile_path = File.join(location, 'anidb.id')
      File.open(idfile_path, 'w') do |f|
        f.write("#{info[:file][:aid]}\n")
      end if !File.exist?(idfile_path) && options[:create_nfo_files]
    end

    def update_symlinks_for(ainfo, folder, location)
      all_locations = [:movies, :incomplete_series, :complete_series,
        :incomplete_other, :complete_other, :adult_location].map {|k| options[:create_symlinks][k] }.compact
      correct_location = decide_symlink_location(ainfo)
      incorrect_locations = all_locations.reject{|a| a == correct_location }
      incorrect_locations.each do |l|
        s = File.join(l, folder)
        if File.symlink?(s)
          File.unlink(s)
          Loggers::Renamer.info "deleting symlink #{s} to #{location}"
        end
      end
      if correct_location && !File.symlink?("#{correct_location}/#{folder}")
        symlink(location, correct_location, folder)
        Loggers::Renamer.info "symlinking #{location} to #{correct_location}/#{folder}"
      end
    end

    def decide_symlink_location(ainfo)
      symlink_locations = options[:create_symlinks]
      return symlink_locations[:adult_location] if ainfo[:is_18_restricted] == "1"
      return symlink_locations[:movies] if ainfo[:type] == "Movie"
      type = ["Web", "TV Series", "OVA", "TV Special"].include?(ainfo[:type]) ? :series : :other
      status = ainfo[:ended] && ainfo[:completed] ? :complete : :incomplete
      symlink_locations["#{status}_#{type}".to_sym]
    end

    def symlink(source, dest, name)
      Symlinker.relative_with_name(source, dest, name)
    rescue Exception => e
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
      resp = RestClient.get(uri, params: {'X-Plex-Token': plex_opt[:token]})
      if resp.code == 200
        Loggers::Renamer.info "Requested plex server at #{uri} to scan library files"
      else
        Loggers::Renamer.error "could not update plex. Got status code #{resp.code} and body #{resp.body}"
      end
    end
  end
end
