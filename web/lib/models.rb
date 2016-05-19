require 'daybreak'
require 'date'
require 'json'

Data_Location = File.join(File.dirname(__FILE__), '../../data')

class Show
  def initialize(aid, name, feed)
    @version = 1
    @id = aid
    @name = name
    @feed = feed
  end  
  
  attr_accessor :name, :feed, :fetched_at, :auto_fetch, :created_at
  attr_reader :version, :id
  
  class << self
    def make
      db = Daybreak::DB.new(File.join(Data_Location, 'shows.db')).tap do |db| 
        at_exit { db.close }
      end
    end

    def close
      @db && @db.close
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
    lock {|db| db[id] = self }
  end
  
  def destroy
    lock {|db| db.delete self.id }
  end
  
  def to_json(*a)
    {
      id: id.to_i,
      name: name,
      created_at: created_at,
      feed: feed
    }.to_json(*a)
  end        
end

at_exit {
  puts "closing database"
  Show.close
}
