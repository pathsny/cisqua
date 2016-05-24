require 'json'
require 'forwardable'
require 'veto'
require_relative 'model'

class FeedItemValidator
  include Veto.validator
end  

class FeedItem
  include Model

  attr_reader :id, :url, :downloaded

  # note changing the order of marshal fields, or adding a field will require 
  # changing the model version and creating a migration
  configure_model(
    :version => 1, 
    :validator => FeedItemValidator,
    :marshal_fields => [:id, :url, :downloaded]
  )

  def initialize(id, url, downloaded)
    super()
    @id = id
    @url = url
    @downloaded = downloaded
  end

  def to_json(*a)
  end  
end 

