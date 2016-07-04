module Options
  # class OptionGroup
  #   def initialize

  # end

  # Misc = OptionGroup.new()
  # 
  class << self
    def[](key)
      return 8 if key == :concurrent_rss_threads
    end  

    def bootstrap_data
      {
        :all_valid => false,
        'config' => config,
      }
    end  

    def config
      [
        {
          :name => 'Torrent',
          :fields => [{
            :name => 'host',
            :label => 'Host',
            :placeholder => '127.0.0.1',
            :type => :text,
          },{
            :name => 'port',
            :label => 'Port',
            :type => :number,
          },{
            :name => 'user',
            :label => 'User Name',
            :placeholder => 'User Name',
            :type => :text,
          },{
            :name => 'pass',
            :label => 'Password',
            :placeholder => 'Password',
            :type => :password,
          }],
        },
      ] 
    end  
  end  
end
