require 'json'
require 'forwardable'
require 'veto'
require 'invariant'
require_relative 'model'


class FeedItemValidator
  include Veto.validator
end  

class FeedItem < Model::Base
  attr_reader :id, :url, :title, :published_at, :downloaded_at, :read_at

  # note changing the order of marshal fields, or adding a field will require 
  # changing the model version and creating a migration
  configure_model(
    :type => :feed_item,
    :version => 1, 
    :validator => FeedItemValidator,
    :fields => [{
      :name => :id,
      :serialize_to_ui => true,
      :mutable => false,
    },{
      :name => :url,
      :serialize_to_ui => true,
      :mutable => false,
    },{
      :name => :title,
      :serialize_to_ui => true,
      :mutable => false,
    },{
      :name => :published_at,
      :serialize_to_ui => true,
      :mutable => false,
    },{
      :name => :summary,
      :serialize_to_ui => true,
      :mutable => false,
    },{
      :name => :downloaded_at,
      :serialize_to_ui => true,
      :mutable => true,
      :default => nil,
      :description => 'timestamp at which we started downloading this file',
    },{
      :name => :hidden_at,
      :serialize_to_ui => true,
      :mutable => true,
      :default => nil,
      :description => 'timestamp at which we hid this file from the interface',
    },{
      :name => :marked_predownloaded_at,
      :serialize_to_ui => true,
      :mutable => true,
      :default => nil,
      :description => 'timestamp at which we marked this file as already being'\
        'downloaded without this interface',
    }]
  )

  def initialize(id, url, title, published_at, summary)
    super()
    @id = id
    @url = url
    @title = title
    @published_at = published_at
    @summary = summary
  end

  def mark_downloaded
    if self.marked_predownloaded_at.nil?
      self.marked_predownloaded_at = DateTime.now 
      save
    end 
  end  

  def unmark_downloaded
    self.marked_predownloaded_at = nil
    save
  end  
end 

