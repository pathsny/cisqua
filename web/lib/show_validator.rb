require 'forwardable'
require 'veto'
require_relative 'feed'

class ShowValidator
  include Veto.validator


  validates :id, :presence => true
  validates :name, :presence => true
  validates :feed, :presence => true
  validates :auto_fetch, :presence => true

  validate :show_must_be_unique, :if => :is_new?

  validate :feed_must_be_valid

  def is_new?(entity)
    entity.is_new?
  end  

  def show_must_be_unique(entity)
    errors.add(:id, "show must be unique") if entity.has_instance_in_db?
  end
  
  def feed_must_be_valid(entity)
    errors.add(:feed, "Invalid feed url") unless Feed.is_valid?(entity.feed)
  end   
end