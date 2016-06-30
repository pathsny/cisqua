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
      {:all_valid => true}
    end  

    def settings_display
      [
        {
          name: 'Torrent',
          valid: false,

        }
      ] 
    end  
  end  
end
