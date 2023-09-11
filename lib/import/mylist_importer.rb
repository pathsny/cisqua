require 'tty-progressbar'
require 'nokogiri'

module Cisqua
  class MylistImporter
    include SemanticLogger::Loggable

    attr_reader :mylist_path, :doc

    def initialize(mylist_path, proxy_client)
      @mylist_path = mylist_path
      @doc = Nokogiri::XML(File.open(File.join(mylist_path, 'mylist.xml')))
      @client = proxy_client
    end

    def run
      errors = []
      logger.info("Importing mylist from #{mylist_path}")
      anime_nodes = doc.xpath('myList/animeList/anime')
      logger.info("Found #{anime_nodes.count} anime nodes")
      updated_at = export_date

      Group.new({
        id: '0',
        name: 'raw/unknown',
        short_name: 'raw',
        updated_at:,
        data_source: 'mylist-import',
      }).save
      importers = anime_nodes.filter_map do |anime_node|
        aid = anime_node['id']

        path = File.join(mylist_path, 'anime', "a#{aid}.xml")
        AnimeXMLImporter.new(aid, path, @client, updated_at)
      end

      first_pass = TTY::ProgressBar.new('Importing Anime [:bar] :current/:total ETA::eta', bar_format: :box, width: 50)
      first_pass.iterate(importers) do |importer|
        logger.debug('Importing anime', { aid: importer.aid, from: importer.path })
        importer.import_anime
      end

      second_pass = TTY::ProgressBar.new('Importing Files [:bar] :current/:total ETA::eta', bar_format: :box, width: 50)

      second_pass.iterate(importers) do |importer|
        logger.debug('Importing files for anime', { aid: importer.aid, from: importer.path })
        importer.import_files
      end

      errors.each do |e|
        logger.error('error importing mylist', { data: e.data, error: e.inner_error })
      end
    rescue ImportError => e
      logger.error('error importing mylist', { data: e.data, error: e.inner_error })
      raise
    rescue StandardError => e
      logger.error('error importing mylist', e.message)
      e.backtrace.each do |line|
        logger.error(line)
      end
    end

    def export_date
      date_str = doc.at_xpath('myList')['creationDate']
      day, month, year = date_str.split('.').map(&:to_i)
      year += 2000 if year < 100 # Assuming only years 2000-2099 are valid
      Time.new(year, month, day).tap do |time|
        logger.info("Creation date #{date_str} #{time}")
      end
    end
  end
end
