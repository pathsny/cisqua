require File.expand_path('../../net/ranidb', __FILE__)

class Anidb
  def initialize(options)
    @client = Net::AniDBUDP.new(*([:host, :port, :localport, :user, :pass, :nat].map{|k| options[k]}))
    @client.connect
    @cache = LRUHash.new(25000)
  end

  def process(*args)
    identify_file(*args).tap do |info|
      return nil if info.nil?
      update_mylist_with info
      aid = info[:file][:aid]
      info[:anime].merge! retrieve_show_details(aid)[:anime]
      info[:anime][:completed] = fetch_mylist_data(aid, info[:anime][:episodes]).tap {|m| m.add info[:anime][:epno] }.complete?
      info
    end
  end

  def update_mylist_with(info)
    logger.debug "adding #{info.inspect} to mylist"
    @client.mylist_add(info[:fid])
  end  

  def method_missing(method, *args)
    maintain_rate_limit
    @client.__send__(method, *args)
  end

  private
  def retrieve_show_details(aid)
    @cache['anime_' + aid] ||= anime(aid)
  end
  
  def fetch_mylist_data(aid, episodes)
    @cache['mylist_' + aid] ||= create_mylist_data(aid, episodes)
  end
  
  def fetch_episode_no(eid)
    @cache['episode_' + eid] ||= episode(eid)[:episode][:epno]
  end  
  
  def create_mylist_data(aid, episodes)
    mylist_hash = mylist_by_aid(aid)[:mylist]
    mylist_hash[:epno] = fetch_episode_no(mylist_hash[:eid]) if (mylist_hash[:single_episode]) 
    MylistData.new(episodes.to_i, mylist_hash)
  end        

  def identify_file(name, size, ed2k)
    search_file(name, size, ed2k).tap do |info|
      @cache['episode_' + info[:file][:eid]] = info[:anime][:epno] if info
      logger.debug "file #{name} identified as #{info.inspect}"
    end
  end    

  def maintain_rate_limit
    diff = Time.now - @now if @now
    sleep 3 - diff if diff && diff < 3
    @now = Time.now
  end  
end
