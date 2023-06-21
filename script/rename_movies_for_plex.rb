# Rename movie files from old format to more plex friendly format

require File.expand_path('../lib/libs', __dir__)
require File.expand_path('helpers/load_options', __dir__)
require 'optparse'
require 'solid_assert'
SolidAssert.enable_assertions

script_options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: rename_movies_for_plex'
  opts.on('-oOPTIONS', '--options=OPTIONS', 'location of options config') do |o|
    script_options[:options_file] = o
  end
  opts.on('--dry-run', 'Dry Run. Does not move any files, create any directories or create symlinks') do
    script_options[:dry_run_mode] = true
  end
  opts.on('--debug', 'Overrides log level in options and sets it to debug') do
    script_options[:log_level] = :debug
  end
  opts.on('--logfile=PATH', 'does not log to default log files and instead logs to provided path') do |path|
    script_options[:logfile] = path
  end
end.parse!
options = ScriptOptions.load_options(script_options[:options_file])
options[:log_level] = script_options[:log_level] if script_options.key?(:log_level)

# we dont want to preserve the old files
options[:renamer][:symlink_source] = false

Loggers.set_log_level_from_option(options[:log_level])
Loggers.custom_log_file(script_options[:logfile]) if script_options.key?(:logfile)

module Loggers
  RenameMoviesForPlex = Logging.logger['RenameMoviesForPlex']
end

class MovieRenamerFoPlex
  def initialize(options, script_options)
    @options = options
    @script_options = script_options
    @errors = []
    @renamer = Renamer::Renamer.new(options[:renamer])
  end

  def run
    root_folder = File.absolute_path(@options.dig(:renamer, :create_symlinks, :movies), ROOT_FOLDER)
    Loggers::RenameMoviesForPlex.info { "processing files in #{root_folder}" }
    Loggers::RenameMoviesForPlex.info { 'DryRun mode is on ' } if @script_options[:dry_run_mode]
    all_folders = Dir[File.join(root_folder, '**')].sort
    all_folders.each do |movie_folder|
      files = file_list(@options[:scanner].merge(basedir: File.realpath(movie_folder)))
      files.each { |movie| plex_rename(File.realpath(movie)) }
    end
    @errors.each { |e| Loggers::RenameMoviesForPlex.error(e) }
  end

  def plex_rename(movie)
    # check if its a old name or renamed file
    fix_symlinks_root = File.absolute_path(@options[:renamer][:fix_symlinks_root], ROOT_FOLDER)

    if /\[\(X/.match(movie)
      work_item = WorkItem.new(movie, extract_info_from_name_assuming_old_scheme(movie))
      @options[:renamer][:dry_run_mode] = @script_options[:dry_run_mode]
      resp = @renamer.try_process(work_item, update_links_from: fix_symlinks_root)
      assert(resp.type == :success, "could not move #{movie}")
      Loggers::RenameMoviesForPlex.info { "moved #{movie} to #{resp.destination}" }
    else
      info = extract_info_from_name_assuming_current_scheme(movie)
      work_item = WorkItem.new(movie, info)

      # we dont expect any changes since this file should be named correctly
      @options[:renamer][:dry_run_mode] = true
      resp = @renamer.try_process(work_item, update_links_from: fix_symlinks_root)
      assert(resp.type == :success, "could not generate new name for #{movie}")
      assert(resp.destination == movie, "location of #{movie} was unexpectedly changed to #{resp.destination}")
      Loggers::RenameMoviesForPlex.info { "did not have to rename #{movie}" }
    end
  rescue StandardError => e
    @errors << e
  end

  def extract_info_from_name_assuming_current_scheme(movie)
    extract_info_from_name(movie, **movie_file_info_using_current_scheme(movie))
  end

  def extract_info_from_name_assuming_old_scheme(movie)
    extract_info_from_name(movie, **movie_file_info_using_old_scheme(movie))
  end

  def extract_info_from_name(movie, movie_file_info)
    aid = File.read(File.join(File.dirname(movie), 'anidb.id')).strip
    {
      file: {
        aid:
      },
      anime: {
        type: 'Movie',
        **movie_file_info
      }
    }
  end

  CURRENT_SCHEME_REGEX = /^ - (?:(?<ep_english_name>Complete Movie|Part \d of \d)|episode (?<epno>\w?\d+(?:-\d+)?) - (?<ep_english_name>[^\[]*))(?: \[(?<group_short_name>[^\]()]*)\])?\.(?<ext>\w*)$/
  def movie_file_info_using_current_scheme(movie)
    dirname = File.dirname(movie)
    romaji_name = File.basename(dirname)
    remaining_name = File.basename(movie).delete_prefix(romaji_name)
    match = CURRENT_SCHEME_REGEX.match(remaining_name)
    if match
      return {
        romaji_name: romaji_name,
        group_short_name: match[:group_short_name] || 'raw',
        epno: match[:epno] || '1',
        ep_english_name: match[:ep_english_name]
      }
    end
    assert(match, "#{movie} did not match pattern")
  end

  OLD_SCHEME_REGEX = /^ - (?<ep_english_name>[^\[]*)(?: \[(?<group_short_name>[^\]()]*)\])? \[\(X(?:S-(?<spc_type>\d+))?-(?<epno>\d+(?:-\d+)?)\)\]\.(?<ext>\w*)$/

  def movie_file_info_using_old_scheme(movie)
    dirname = File.dirname(movie)
    romaji_name = File.basename(dirname)
    remaining_name = File.basename(movie).delete_prefix(romaji_name)
    match = OLD_SCHEME_REGEX.match(remaining_name)
    assert(match, "#{movie} did not match pattern")

    epno =
      case match[:spc_type]
      when nil
        match[:epno]
      when '0'
        "S#{match[:epno]}"
      else
        "#{(match[:spc_type].to_i - 100 + 64).chr}#{match[:epno]}"
      end
    {
      romaji_name:,
      group_short_name: match[:group_short_name] || 'raw',
      epno:,
      ep_english_name: match[:ep_english_name]
    }
  end
end

renamer = MovieRenamerFoPlex.new(options, script_options)
renamer.run
