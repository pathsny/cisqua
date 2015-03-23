require 'daybreak'
require 'date'
require 'json'

Data_Location = File.join(File.dirname(__FILE__), '..', 'data')

class Show
  def initialize(aid, name)
    @version = 1
    @aid = aid
    @name = name
  end  
  
  attr_accessor :name, :feed, :fetched_at, :auto_fetch, :created_at
  attr_reader :version, :aid
  
  class << self
    def make
      db = Daybreak::DB.new(File.join(Data_Location, 'shows.db')).tap do |db| 
        at_exit { db.close }
      end
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
    
    def get(aid)
      lock { |db| db[aid].tap { |s| raise "invalid id" unless s } }
    end
  end
  
  def lock(&b)
    self.class.lock &b
  end  
  
  def save
    lock {|db| db[aid] = self }
  end
  
  def destroy
    lock {|db| db.delete self.aid }
  end
  
  def to_json(*a)
    {
      aid: aid,
      name: name,
      created_at: created_at
    }.to_json(*a)
  end        
end