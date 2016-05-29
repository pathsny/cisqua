require 'daybreak'
require 'concurrent'

class ModelDB
  @dbs = Concurrent::Map.new
  Kernel.at_exit { close_dbs }

  Data_location = File.join(File.dirname(__FILE__), '../../data/db')

  class << self
    def get_db(name)
      db = @dbs.compute_if_absent(name) {
        Daybreak::DB.new(File.join(Data_location, name + '.db'))
      }
      db.synchronize {
        yield db
      }        
    end

    def close_dbs
      puts "closing databases"
      thr = Thread.new do
        @dbs.values.each {|db| db.flush.close unless db.closed? }
      end
      thr.join
    end  
  end
end      


module Model
  def self.included(base)
    base.extend(ClassMethods)
    base.instance_variable_set(:@model_key, base.name.downcase + '_')
  end
  
  module ClassMethods
    private
    def is_key_of_model?(k) #bool
      k.start_with?(@model_key)
    end

    def make_key(id)
      @model_key + id.to_s
    end  

    def configure_model(options)
      self.instance_variable_set(:@current_version, options[:version])
      self.include(Veto.model(options[:validator].new))

      symbol_list = [:version, :created_at, :updated_at].concat(options[:marshal_fields])
      var_list = symbol_list.map {|f| "@#{f}"}.join(',')

      self.class_eval("def marshal_dump; [#{var_list}]; end")
      self.class_eval("def marshal_load(dump); #{var_list} = dump; @new_record = false; end")
    end  

    public 
    attr_reader :current_version

    def all
      ModelDB.get_db('shows') do |db| 
        db.select {|k, v| is_key_of_model?(k) }.map{|k, v| v} 
      end  
    end
    
    def get(id)
      ModelDB.get_db('shows') do |db|
        db[make_key(id)].tap { |s| raise "invalid id" unless s }
      end  
    end

    def exists?(id)
      ModelDB.get_db('shows') do |db|
        db.has_key?(make_key(id))
      end  
    end  

    def create(*args)
      self.new(*args)
    end  
  end

  private
    def current_version
      self.class.send(:current_version)
    end

    def make_key(id)
      self.class.send(:make_key, id)
    end

  public

  attr_reader :created_at, :updated_at, :version    

  def initialize
    @new_record = true
    @version = current_version
  end

  def new_record?
    @new_record
  end

  def has_instance_in_db?
    return false unless self.id
    self.class.exists?(self.id)
  end  

  def save
    validate!
    ModelDB.get_db('shows') do |db|
      @created_at = DateTime.now if self.new_record?
      @new_record = false
      @updated_at = DateTime.now
      db[make_key(id)] = self
    end
  end

  def destroy!
    ModelDB.get_db('shows') do |db|
      db.delete(make_key(self.id))
    end  
  end
end  
