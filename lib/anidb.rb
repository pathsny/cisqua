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
      info[:anime].merge! retrieve_show_details(info[:file][:aid])[:anime]
      # verify_if_show_is_complete_using info
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

  def verify_if_show_is_complete_using(info)
    anime_details = retrieve_show_details(info[:file][:aid])
    mylist_anime_details = mylist_by_fid(info[:fid]) 
    puts anime_details.inspect
    puts mylist_anime_details.inspect
  end

  def retrieve_show_details(aid)
    @cache['anime_' + aid] ||= anime(aid).tap{|x| puts x.inspect}    
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