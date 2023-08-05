require 'yaml'

module Cisqua
  module StrictInitialize
    extend Reloadable

    reloadable_const_define :ALLOWED_TYPES, [String, Numeric, TrueClass, FalseClass, Array, Struct].freeze

    def initialize(**kwargs)
      missing = members - kwargs.keys
      extra = kwargs.keys - members
      assert(missing.empty?, "#{self.class.name} initialized without keys #{missing}")
      assert(extra.empty?, "#{self.class.name} initialized with unknown keys #{extra}")
      invalid_value_types = kwargs.keys.select do |k|
        value = kwargs[k]
        ALLOWED_TYPES.all? { |klass| !value.is_a?(klass) }
      end
      assert(
        invalid_value_types.empty?,
        "#{self.class.name} initialized with keys with invalid value types #{invalid_value_types}",
      )
      super(**kwargs)
    end
  end

  reloadable_const_define :ScannerOptions, Struct.new(
    # the location where you keep your anime to be scanned
    :basedir,
    # list of file extensions to scan
    :extensions,
    # if this is false. Only the top level files of each directory in the basedir are scanned.
    # if this is true, all the files are picked up recursively
    :recursive,
    keyword_init: true,
  ) do
    include StrictInitialize
  end

  # configuration details for the api
  reloadable_const_define :AnidbOptions, Struct.new(
    :port,
    :host,
    :localport,
    :nat,
    :user,
    :pass,
    keyword_init: true,
  ) do
    include StrictInitialize
  end

  reloadable_const_define :APIClientOptions do
    Struct.new(
      # connection settings to connect to anidb
      :anidb,
      # set this to true to add all identified files to your mylist
      :add_to_mylist,
      keyword_init: true,
    ) do
      include StrictInitialize
    end
  end

  reloadable_const_define :SymlinkLocationOptions do
    Struct.new(
      :movies,
      :incomplete_series,
      :complete_series,
      :incomplete_other,
      :complete_other,
      # set this to a non null value if adult shows should be symlinked to a folder
      :adult_location,
      keyword_init: true,
    ) do
      include StrictInitialize
    end
  end

  reloadable_const_define :PlexScanLibraryOption do
    Struct.new(
      # needed to update plex server after files have been renamed.
      :token,
      :host,
      :port,
      :section,
      keyword_init: true,
    ) do
      include StrictInitialize
    end
  end

  reloadable_const_define :RenamerOptions do
    Struct.new(
      # list of extensions for subtitle files. If a show is present with a subtitle, the subtitle is also copied
      :subtitle_extensions,
      # location to store anime.
      :output_location,
      # location to store files that are duplicates.
      :duplicate_location,
      # location to store files that are duplicates that can be deleted.
      :junk_duplicate_location,
      # location to store files that are unknown.
      :unknown_location,
      # set this to true if you want a symlink back to the source where the files were moved
      :symlink_source,
      # when replacing an existing file, searches this folder for symlinks and updates them
      # to the new location. Most likely same as basedir.
      :fix_symlinks_root,
      # create symlinks to access anime by type and completeness factor. can be false, or a nested hash
      :create_symlinks,
      # needed to make sure plex identifies anime
      :create_anidb_id_files,
      # needed to update plex server after files have been renamed.
      :plex_scan_library_files,
      # when dry_run_mode is set, no files are moved and no directories are created
      :dry_run_mode,
      keyword_init: true,
    ) do
      include StrictInitialize
    end
  end

  reloadable_const_define :Options do
    Struct.new(
      :api_client,
      :scanner,
      :renamer,
      # set this to false if you want the base directory left alone. Otherwise this removes all directories that can be
      # safely removed. i.e either they're empty or contain only empty directories
      :clean_up_empty_dirs,
      # the default log level in the logs
      :log_level,
      keyword_init: true,
    ) do
      include StrictInitialize

      def self.load_options(options_file = nil)
        options_file ||= File.join(DATA_FOLDER, 'options.yml')
        option_args = YAML.load_file(options_file)
        make_options(option_args)
      end

      def self.make_options(option_args)
        Options.new(**option_args.each_with_object({}) do |(k, v), m|
          m[k] = case k
          when :api_client
            make_api_client_options(v)
          when :scanner
            ScannerOptions.new(**v)
          when :renamer
            make_renamer_options(v)
          else
            v
          end
        end)
      end

      def self.make_api_client_options(option_args)
        APIClientOptions.new(**option_args.each_with_object({}) do |(k, v), m|
          m[k] = case k
          when :anidb
            AnidbOptions.new(**v)
          else
            v
          end
        end)
      end

      def self.make_renamer_options(option_args)
        RenamerOptions.new(**option_args.each_with_object({}) do |(k, v), m|
          m[k] = case k
          when :plex_scan_library_files
            v && PlexScanLibraryOption.new(**v)
          when :create_symlinks
            SymlinkLocationOptions.new(**v)
          else
            v
          end
        end)
      end
    end
  end
end
