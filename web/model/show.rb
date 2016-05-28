require_relative 'model'
require 'forwardable'
require 'veto'
require 'json'
require_relative '../lib/feed_processor'


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

class Show
  include Model

  attr_reader :id, :name, :feed_url, :auto_fetch  

  # note changing the order of marshal fields, or adding a field will require 
  # changing the model version and creating a migration
  configure_model(
    :version => 1, 
    :validator => ShowValidator,
    :marshal_fields => [:id, :name, :feed_url, :auto_fetch]
  )

  def initialize(id, name, feed_url, auto_fetch)
    super()
    @id = id.to_i
    @name = name
    @feed_url = feed_url
    @auto_fetch = auto_fetch
  end

  def to_json(*a)
    {
      id: id,
      name: name,
      created_at: created_at,
      feed_url: feed_url,
      auto_fetch: auto_fetch
    }.to_json(*a)
  end
end  
