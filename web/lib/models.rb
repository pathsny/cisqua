require 'daybreak'
require 'date'
require 'json'
require_relative 'show_validator'

Data_Location = File.join(File.dirname(__FILE__), '../../data')

class Show
  include Veto.model(ShowValidator.new)

  def initialize(id, name, feed, auto_fetch)
    @version = 1
    @id = id
    @name = name
    @feed = feed
    @auto_fetch = auto_fetch
    @is_new = true
  end  
  
  attr_accessor :name, :feed, :auto_fetch, :errors
  attr_reader :version, :id, :created_at, :updated_at
  
  class << self
    def make
      db = Daybreak::DB.new(File.join(Data_Location, 'shows.db')).tap do |db| 
        at_exit { db.close }
      end
    end

    def closed?
      return true unless @db
      @db.closed?
    end  

    def close
      @db && @db.flush.close
    end   
    
    def lock
      @db ||= make
      @db.lock {
        yield @db
      }
    end
    
    def all
      lock { |db| db.map {|k, v| v} }
    end
    
    def get(id)
      lock { |db| db[id].tap { |s| raise "invalid id" unless s } }
    end

    def exists?(id)
      lock { |db| db.has_key?(id) }
    end  
  end
  
  def lock(&b)
    self.class.lock &b
  end  
  
  def save
    validate!
    lock do |db|
      db[id] = self.clone.tap {|c| 
        c.send(:remove_instance_variable, :@is_new)
        c.instance_variable_set(:@created_at, DateTime.now) if is_new
        c.instance_variable_set(:@updated_at, DateTime.now)
      } 
    end  
  end

  def has_instance_in_db?
    return false unless self.id
    self.class.exists?(self.id)
  end  

  def is_new?
    @is_new
  end

  def destroy
    lock {|db| db.delete self.id }
  end
  
  def to_json(*a)
    {
      id: id.to_i,
      name: name,
      created_at: created_at,
      feed: feed,
      auto_fetch: auto_fetch
    }.to_json(*a)
  end        
end

at_exit do
  puts "closing database"
  unless Show.closed?
    thr = Thread.new { Show.close }
    thr.join
  end  
end
