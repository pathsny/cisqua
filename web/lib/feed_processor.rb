require 'feedjira'

class FeedProcessor
  class << self
    def is_valid?(url)
      Feedjira::Feed.fetch_and_parse(url)
      true
    rescue
      false
    end  
  end  
end  