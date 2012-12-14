require 'set'

class MylistData
  class Single
    class << self
      def add(ep); end
      def normal_episodes; [1]; end
      def special_episodes; []; end
      def complete?; true; end 
    end  
  end  
  
  def self.new(params)
    return MylistData::Single if params[:single_episode]
    super
  end
    
  def initialize(params)
    @episodes = process_ranges [:unknown_ep_list, :hdd_ep_list, :cd_ep_list].map {|t| params[t].split(',')}.flatten
    @count = params[:episodes].to_i rescue 0
  end
  
  def add(ep)
    @episodes.add ep =~ /^\d+$/ ? ep.to_i : ep
  end  
  
  def normal_episodes
    @episodes.select {|e| e.is_a? Integer}
  end
  
  def special_episodes
    @episodes.reject {|e| e.is_a? Integer}
  end
  
  def complete?
    @count > 0 && normal_episodes.size == @count 
  end
  
  private
  def process_ranges(ranges)
    pieces = ranges.map do |r| 
      if r =~ /^[A-Z]*\d+-[A-Z]*\d+$/
        parts = r.split('-')
        (parts[0]..parts[1]).to_a
      else 
        r      
      end  
    end
    Set.new pieces.flatten.map {|k| k =~ /^\d+$/ ? k.to_i : k}  
  end  
end