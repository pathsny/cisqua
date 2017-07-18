require 'daybreak'
require 'concurrent-edge'
require_relative '../../lib/loggers.rb'

module Model
  class ModelDB
    @dbs = Concurrent::Map.new
    Kernel.at_exit { close_dbs }

    Data_location = File.expand_path(File.join(
      File.dirname(__FILE__), 
      '../../data/db'
    ))

    class << self
      def get_db(db_name)
        db = @dbs.compute_if_absent(db_name) {
          Loggers::DB.debug { "opening db #{db_name}" }
          Daybreak::DB.new(File.join(Data_location, db_name + '.db'))
        }
        db.synchronize {
          yield db
        }        
      end

      def destroy(db_name)
        Loggers::DB.debug { "destroying database #{db_name}" }
        db = @dbs[db_name]
        @dbs.delete(db_name)
        return unless db
        db.synchronize { db.flush.close unless db.closed? }  
        File.delete(File.join(Data_location, db_name + '.db'))
      end  

      def close_dbs
        Loggers::DB.debug { "closing databases" }
        thr = Thread.new do
          @dbs.values.each {|db| db.flush.close unless db.closed? }
        end
        thr.join
      end  
    end
  end  

  class Collection
    def initialize(db_name, instance_klass)
      @db_name = db_name
      @instance_klass = instance_klass
      @destroyed = false
    end

    attr_reader :db_name

    def all
      with_db { |db|  db.map{|k, v| v} } 
    end
    
    def get(id)
      with_db do |db|
        assert(db.has_key?(id), "invalid id #{id}")
        db[id]
      end  
    end

    def exists?(id)
      with_db {|db| db.has_key?(id) }
    end  

    def create(*args)
      @instance_klass.send(:new, db_name, *args)
    end

    def destroy!
      @destroyed = true
      Model.destroy_collection(@db_name)
    end      

    private
    def with_db(&b)
      raise "db was destroyed" if @destroyed
      ModelDB.get_db(@db_name, &b)
    end

    def save(id, instance)
      with_db { |db| db[id] = instance }
    end
    
    def delete(id)
      with_db {|db| db.delete(id) }
    end
  end    


  # based on configuration data. Created during configuration
  @model_types = {}

  # models corresponding to each db. Created on demand
  @model_collections = Concurrent::Map.new

  def self.get_collection(type, db_name)
    assert(@model_types.has_key?(type), "invalid model type #{type}")
    @model_collections.compute_if_absent(db_name) {
      Collection.new(db_name, @model_types[type])
    }
  end

  def self.destroy_collection(db_name)
    @model_collections.delete(db_name)
    ModelDB.destroy(db_name)
  end  

  def self.add_type(type, instance_klass)
    assert(!@model_types.has_key?(:type), "duplicate model with type #{type}")
    @model_types[type] = instance_klass
  end

  def self.get_type(type)
    @model_types[type]
  end    

# Model Fields
# name (self explanatory)
# serialize_to_ui (what you get when you call to_json)
# mutable (has setter)
# description (self explanatory)
# default (self explanatory)

  class Base
    class << self

      def configure_model(options)
        [:type, :validator, :version, :fields].each { |opt_key|
          assert(options.has_key?(opt_key), "model must have key #{opt_key}") 
        }
        @type = options[:type]
        @current_version = options[:version]

        Model.add_type(options[:type], self)
        self.include(Veto.model(options[:validator].new))

        configure_fields(options[:fields])
      end

      attr_reader :type, :current_version

      private

      def new(db_name, *args)
        allocate.tap do |instance|
          instance.instance_variable_set(:@db_name, db_name)
          instance.instance_variable_set(:@version, @current_version)
          instance.send(:initialize, *args)
          check_fields_after_initialize(instance)
        end
      end

      def check_fields_after_initialize(instance)
        @auto_fields.each do |f|
          is_defined = instance.instance_variable_defined?(f[:field_name])
          assert(
            is_defined, 
            "#{f[:field_name]} was not defined on initialize",
          ) unless f.has_key?(:default)
          if !is_defined && f.has_key?(:default)
            instance.instance_variable_set(f[:field_name], f[:default])
          end  
        end
      end  

      def configure_fields(fields)
        @auto_fields = fields.
          reject {|f| f[:custom_impl]}.
          map {|f| f.merge(:field_name => "@#{f[:name]}")}
        attr_reader(* @auto_fields.map {|f| f[:name] })
        mutable_fields = @auto_fields.select {|f| f[:mutable]}
        dirty_tracking_field_accessor(* mutable_fields)
        configure_marshalling(@auto_fields.map{|f| f[:field_name]})
        configure_to_json(fields.select{|f|f[:serialize_to_ui]}.map{|f| f[:name]})
      end

      def dirty_tracking_field_accessor(*fields)
        fields.each do |field|
          m = <<-RDEF.gsub(/^\s+/, '')
          def #{field[:name]}=(value)
            @dirty_fields[:#{field[:name]}] = #{field[:field_name]} unless @dirty_fields.has_key?(:name)
            #{field[:field_name]} = value
          end            
          RDEF
          self.class_eval(m)      
        end  
      end  
      
      def configure_marshalling(marshal_fields)
        symbol_list = [:@version, :@db_name, :@created_at, :@updated_at].concat(marshal_fields)
        vars = symbol_list.join(',')
        self.class_eval("def marshal_dump; [#{vars}]; end")
        m = <<-MDEF.gsub(/^\s+/, '')
          def marshal_load(dump)
            #{vars} = dump
            @new_record = false
            @dirty_fields = {}
            self.class.send(:check_fields_after_initialize, self)
          end 
        MDEF
        self.class_eval(m)
      end

      def configure_to_json(json_fields)
        json_def = json_fields.
          concat([:created_at, :updated_at]).
          map {|f| "#{f}: #{f}"}.
          join(",")
        self.class_eval("def to_hash_for_json; {#{json_def}}; end")  
        self.class_eval("def to_json(*a); self.to_hash_for_json.to_json(*a); end")
      end        
    end

    attr_reader :created_at, :updated_at, :version

    def initialize
      @new_record = true
      @dirty_fields = {}
    end

    def new_record?
      @new_record
    end

    def has_instance_in_db?
      return false unless self.id
      collection.exists?(self.id)
    end  

    def save
      validate!
      was_new = @new_record
      @created_at = DateTime.now if was_new
      @new_record = false
      @updated_at = DateTime.now
      collection.send(:save, self.id, self)
      result = on_save(was_new, was_new ? {} : @dirty_fields.select do|k, v|
        v != self.send(k) 
      end)
      @dirty_fields = {}
      result
    end

    def on_save(was_new, dirty_fields)
      Loggers::DB.debug { "saved #{was_new ? 'new' : 'existing'} object of "\
        "type #{@db_name} and id #{id}" }
      Concurrent.succeeded_future(true) 
    end  

    def destroy!
      collection::send(:delete, self.id)
      on_destroy
    end

    def on_destroy
      Loggers::DB.debug { "destroyed object of type #{@db_name} and id #{id}"}
      Concurrent.succeeded_future(true)
    end  

    def collection
      Model::get_collection(self.class.type, @db_name)
    end  
  end
end     
