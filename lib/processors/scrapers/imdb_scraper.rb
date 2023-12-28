require 'faraday'

module Cisqua
  class ImdbScraper
    include SemanticLogger::Loggable
    def initialize(tmdb_scraper)
      @tmdb_scraper = tmdb_scraper
    end

    def fetch_images(meta)
      @tmdb_scraper.fetch_images_by_imdb_id(meta.source_id)
    end
  end
end
