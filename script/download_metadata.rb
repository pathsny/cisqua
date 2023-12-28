# Main entry point for rename script. Checks with anidb, adds to mylist etc
require File.expand_path('../lib/libs', __dir__)
require File.join(Cisqua::ROOT_FOLDER, 'integration_spec', 'test_util')
require 'optparse'
require 'tty-progressbar'

module Cisqua
  class MetadataDownloader
    include SemanticLogger::Loggable

    def initialize(scraper)
      @scraper = scraper
    end

    def set_metadata
      report = {}

      MyList.anime_ids.each do |id|
        @scraper.ensure_metadata_only(id)
        anime = Anime.find(id)
        m = anime.metadata
        h = anime.is_18_restricted
        if !m.nil?
          report[m.source] = (report[m.source] || 0) + 1
        elsif h
          report[:missing_h] = (report[:missing_h] || 0) + 1
        else
          report[:missing] = (report[:missing] || 0) + 1
        end
      rescue Invariant::AssertionError, StandardError => e
        logger.error('error while fetching metadata for', id:, error: e)
      end
      ap report
    end

    def download_images
      metas = MyList.anime_ids.map { |id| Anime.find(id).metadata }
      candidates = metas.select do |m|
        m &&
          !m.image_fetch_attempted? &&
          @scraper.image_fetch_supported(m)
      end
      progress = TTY::ProgressBar.new('Downloading Images [:bar] :current/:total ETA::eta', bar_format: :box, width: 50)
      progress.iterate(candidates) do |candidate|
        @scraper.fetch_image_from_meta(candidate)
      rescue Invariant::AssertionError, StandardError => e
        logger.error('error while fetching metadata for', id: candidate.id, error: e)
      end
    end

    def run(mode)
      case mode
      when :meta
        set_metadata
      when :image
        download_images
      end
    end
  end

  script_options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: initialize_ranges'
    opts.on('-t', '--test', 'run for testing') do
      script_options[:test_mode] = true
    end
    opts.on('-s', '--start-redis', 'starts and stops redis server') do
      script_options[:start_redis] = true
    end
    opts.on('-o', '--override', 'updates metadata even if it already has a value') do
      script_options[:override] = true
    end
    opts.on('-m', '--mode MODE', %w[meta image], 'Select mode: meta or image') do |mode|
      script_options[:mode] = mode.to_sym
    end
  end.parse!

  assert(script_options.key?(:mode), 'Mode must be specified')

  AppLogger.log_level = :info
  Registry.options_file_override = script_options[:options_file]
  if script_options[:test_mode]
    TestUtil.prep_registry
  end
  registry = Registry.instance
  downloader = MetadataDownloader.new(
    registry.make_metadata_scraper(
      override: script_options[:override],
    ),
  )
  if script_options[:start_redis]
    RedisScripts.instance.with_redis(registry.options.redis.conf_path) do
      downloader.run(script_options[:mode])
    end
  else
    downloader.run(script_options[:mode])
  end
end
