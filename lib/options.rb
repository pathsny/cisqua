require 'invariant'
require 'net/ping'
require 'trans-api'
require 'veto'

module Options
  FileLocation = File.join(File.dirname(__FILE__), '../data/options.json')

  class OptionGroup
    UI_CONFIG_KEYS = Set.new([:name, :label, :fields])

    def initialize(config)
      @config = config
      @field_names = Set.new(@config[:fields].map {|f| f[:name]})
      @struct = Struct.new(*@field_names.to_a)
      @validator = Class.new do 
        include Veto.validator
        instance_eval &config[:validations]
      end  
    end

    attr_reader :values

    def name
      @config[:name]
    end

    def ui_config
      @config.select {|k, v| UI_CONFIG_KEYS.include?(k)}
    end    

    def [](key)
      assert(@field_names.include?(key), 'invalid key')
      @values[key]
    end

    def update!(values)
      @values = {}
      @config[:fields].each do |f| 
        name = f[:name].to_s
        @values[name] = values[name]
        @values[name] = f[:default] if @values[name].nil?
      end
    end

    def validate!
      s = @struct.new(*@field_names.map {|n| @values[n.to_s]})
      @validator.new.validate!(s)
    end

    def valid?
      s = @struct.new(*@field_names.map {|n| @values[n.to_s]})
      @validator.new.valid?(s)
    end
  end

  @option_groups = []  

  class << self
    def load_data
      t = File.read(FileLocation) rescue '{}'
      json = JSON.parse(t) rescue {}
      data = json.is_a?(Hash) ? json : {}
      @option_groups.each do |option_group|
        option_group.update!(data[option_group.name] || {})
      end  
    end

    def value_hash
      Hash[@option_groups.map {|og| [og.name, og.values]}]
    end  

    def save(name, option_values)
      option_group = const_get(name) rescue nil
      option_group.update!(option_values)
      File.open(FileLocation, 'w') do |f| 
        f.puts(JSON.pretty_generate(values))
      end  
      option_group.validate!  
    end    

    def configure(configuration)
      configuration.each do |cg|
        option_group = OptionGroup.new(cg)
        self.const_set(cg[:name], option_group)
        @option_groups << option_group 
      end
    end

    def bootstrap_data
      {
        'config' => @option_groups.map(&:ui_config),
        'valid' => Hash[@option_groups.map {|og| [og.name, og.valid?]}]
      }
    end

    def values
      Hash[@option_groups.map {|og| [og.name, og.values] }]
    end
  end

  configure [{
    :name => 'Torrent',
    :label => 'Torrent Settings',
    :fields => [{
      :name => :host,
      :label => 'Host',
      :placeholder => '127.0.0.1',
      :type => :text,
    },{
      :name => :port,
      :label => 'Port',
      :type => :number,
      :default => 9091,
    },{
      :name => :user,
      :label => 'User Name',
      :placeholder => 'User Name',
      :type => :text,
    },{
      :name => :pass,
      :label => 'Password',
      :placeholder => 'Password',
      :type => :password,
    }],
    :validations => Proc.new { 
      validates :host, :presence => true
      validates :port, :presence => true, :numeric => true, :inclusion => 1..65535
      validates :user, :presence => true
      validates :pass, :presence => true
      validate :host_is_pingable, :if => :host_set?
      validate :configuration_is_correct, :if => :pingable?

      define_method :host_set? do |entity|
        entity.host
      end  

      define_method :pingable? do |entity|
        host_set?(entity) && Net::Ping::External.new(entity.host).ping?
      end

      define_method :host_is_pingable do |entity|
        errors.add(:host, "cannot be pinged") unless pingable?(entity)
      end  

      define_method :configuration_is_correct do |entity|
        res = Trans::Api::Connect.new entity.to_h
        errors.add(:host, "and then what?")
      end  
    }
  },{
    :name => 'Misc',
    :label => 'Miscellaneous',
    :fields => [{
      :name => :concurrent_rss_threads,
      :label => 'Concurrent RSS Threads',
      :placeholder => 8,
      :default => 8,
      :type => :number,
    }],
    :validations => Proc.new {
      validates :concurrent_rss_threads, :numeric => true, :greater_than => 1
    }  
  }]
  load_data 
end
