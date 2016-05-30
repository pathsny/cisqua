require 'json'
require 'forwardable'
require 'veto'
require_relative 'model'

class FeedItemValidator
  include Veto.validator
end  

class FeedItem < Model::Base
  attr_reader :id, :url, :downloaded

  # note changing the order of marshal fields, or adding a field will require 
  # changing the model version and creating a migration
  configure_model(
    :type => :feed_item,
    :version => 1, 
    :validator => FeedItemValidator,
    :fields => [{
      :name => :id,
      :serialize_to_ui => true,
      :mutable => false
    },{
      :name => :url,
      :serialize_to_ui => true,
      :mutable => false
    },{
      :name => :downloaded,
      :serialize_to_ui => true,
      :mutable => true
    }]

  )

  def initialize(id, url, downloaded)
    super()
    @id = id
    @url = url
    @downloaded = downloaded
  end
end 

