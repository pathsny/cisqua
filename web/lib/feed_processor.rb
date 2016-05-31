require 'feedjira'
require 'set'
require 'concurrent-edge'
require_relative '../model/show'
require_relative '../model/feed_item'
require_relative './constants'

class FeedProcessor
  @executor = Concurrent::ThreadPoolExecutor.new(
    :max_threads => ::Options[:concurrent_rss_threads]
  )
  @is_updating_feed_items = Concurrent::AtomicBoolean.new
  @is_updating_show_feed_items = Concurrent::Map.new

  Kernel.at_exit {
    puts "shutting down thread pool"
    @executor.shutdown
    @executor.wait_for_termination
  }

  class << self
    def is_valid?(url)
      Feedjira::Feed.fetch_and_parse(url)
      true
    rescue
      false
    end

    def is_updating_feed_items?
      @is_updating_feed_items.value
    end

    def is_updating_show_feed_items?(id)
      @is_updating_show_feed_items.key?(id)
    end

    def update_all_shows
      res = @is_updating_feed_items.make_true
      return unless res # someone has already started this process
      futures = Show.all.map {|s| FeedProcessor.update_show(s.id) }
      Concurrent.zip(*futures).on_completion {
        @is_updating_feed_items.make_false
      } 
    end  

    def update_show(id)
      return @is_updating_show_feed_items.compute_if_absent(id) do
        Concurrent.future(@executor) {
          update_show_impl(id)
        }.then(:io) {
          @is_updating_show_feed_items.delete(id) 
        }.rescue(:io) { |reason|
          @is_updating_show_feed_items.delete(id) 
        }
      end
    end  

    private

    def update_show_impl(id)
      show = Show.get(id)
      feed_entries = Feedjira::Feed.fetch_and_parse(show.feed_url).entries
      feed_collection = show.feed

      existing_item_ids = Set.new(feed_collection.all.map(&:id))
      new_entries = feed_entries.reject {|entry| existing_item_ids.include?(entry.entry_id) }
      
      new_entries.each do |entry| 
        feed_collection.create(
          entry.entry_id, 
          entry.url, 
          entry.title, 
          entry.published,
          entry.summary,
        ).save
      end
      show.last_checked_at = DateTime.now
      show.latest_feed_item_added_at = DateTime.now unless new_entries.empty?
      show.save
    end  
  end  
end  