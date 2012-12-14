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
      puts info[:anime].inspect
      info[:anime].merge! retrieve_show_details(aid)[:anime]
      info[:anime][:completed] = fetch_mylist_data(aid).tap {|m| m.add info[:anime][:epno] }.complete?
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

  def retrieve_show_details(aid)
    @cache['anime_' + aid] ||= anime(aid)
  end
  
  def fetch_mylist_data(aid)
    @cache['mylist_' + aid] ||= MylistData.new(mylist_by_aid(aid)[:mylist]).tap{|k| puts k.inspect}
  end      

  private

  def identify_file(name, size, ed2k)
    search_file(name, size, ed2k).tap do |info|
      logger.debug "file #{name} identified as #{info.inspect}"
    end
  end    

  def maintain_rate_limit
    diff = Time.now - @now if @now
    sleep 2 - diff if diff && diff < 2
    @now = Time.now
  end  
end        