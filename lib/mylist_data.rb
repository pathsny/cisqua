require 'set'

class MylistData
  def initialize(count, params)
    data = params[:single_episode] ? [params[:epno]] : [:unknown_ep_list, :hdd_ep_list, :cd_ep_list].map {|t| params[t].split(',')}.flatten
    @episodes = process_ranges(data)
    @count = count
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
      match = /^([A-Z])?(\d+)-\1?(\d+)$/.match r
      if match
        puts match.inspect
        ((match[2].to_i)..(match[3].to_i)).map {|x| "#{match[1]}#{x}"}
      else 
        r      
      end  
    end
    Set.new pieces.flatten.map {|k| k =~ /^\d+$/ ? k.to_i : k}  
  end  
end