require_relative 'model'
require_relative 'feed_item'
require 'forwardable'
require 'veto'
require 'json'
require_relative '../lib/feed_processor'
require 'invariant'


class ShowValidator
  include Veto.validator

  validates :id, :presence => true
  validates :name, :presence => true
  validates :feed_url, :presence => true
  validates :auto_fetch, :presence => true

  validate :show_must_be_unique, :if => :new_record?

  validate :feed_url_must_be_valid

  def new_record?(entity)
    entity.new_record?
  end  

  def show_must_be_unique(entity)
    errors.add(:id, "show must be unique") if entity.has_instance_in_db?
  end
  
  def feed_url_must_be_valid(entity)
    errors.add(:feed_url, "Invalid feed url") unless FeedProcessor.is_valid?(entity.feed_url)
  end   
end

class ShowInstance < Model::Base

  # note changing the order of fields, or adding a field will require 
  # changing the model version and creating a migration, if the field is serialized
  # to disk
  configure_model(
    :type => :show,
    :version => 1, 
    :validator => ShowValidator,
    :fields => [{
      :name => :id,
      :serialize_to_ui => true,
      :mutable => false,
    },{
      :name => :name,
      :serialize_to_ui => true,
      :mutable => false,
    },{
      :name => :feed_url,
      :serialize_to_ui => true,
      :mutable => false,
      :description => 'url for rss feed',
    },{
      :name => :auto_fetch,
      :serialize_to_ui => true,
      :mutable => true,
      :description => 
        'flag indicating that we should automatically download new episodes'\
         ' as they are ready',
    },{
      :name => :is_updating_feed_items,
      :custom_impl => true,
      :serialize_to_ui => true,
      :description => 'flag indicating that we are currently refreshing the'\
        ' feed items for this show',
    },{
      :name => :last_checked_at,
      :serialize_to_ui => true,
      :mutable => true,
      :default => nil,
      :description => 'timestamp at which we last checked the feed for new items',
    },{
      :name => :latest_feed_item_added_at,
      :serialize_to_ui => true,
      :mutable => true,
      :default => nil,
      :description => 'timestamp at which we last added a feed item',
    }]
  )

  def initialize(id, name, feed_url, auto_fetch)
    super()
    @id = id
    @name = name
    @feed_url = feed_url
    @auto_fetch = auto_fetch.is_a?(String) ? auto_fetch == 'true' : auto_fetch
  end

  def on_save(was_new, dirty_fields)
    result = super
    was_new ? FeedProcessor.update_show(id) : result
  end
    
  def feed
    assert(!self.new_record?, "feeds should not be fetched for unsaved shows")
    Model.get_collection(:feed_item, self.id)
  end

  def is_updating_feed_items
    FeedProcessor.is_updating_show_feed_items?(self.id)
  end

  def to_hash_for_json_with_feed_items
    self.to_hash_for_json.merge(
      feed_items: feed.all
    )
  end  

  def to_json_with_feed_items(*a)
    self.to_hash_for_json_with_feed_items.to_json(*a)
  end

  def on_destroy
    result = super
    feed.destroy!
    result
  end    
end

Show = Model.get_collection(:show, 'shows')  
