require File.join(ROOT_FOLDER, 'net/ranidb')
require File.join(ROOT_FOLDER, 'external/lru_hash')

class Anidb
  def initialize(options)
    @options = options
    @cache = LRUHash.new(25_000)
  end

  def process(*args)
    identify_file(*args).tap do |info|
      return nil if info.nil?

      update_mylist_with info
      aid = info[:file][:aid]
      info[:anime].merge! retrieve_show_details(aid)[:anime]
      info[:anime][:completed] = fetch_mylist_data(aid, info[:anime][:episodes]).tap do |m|
        m.add info[:anime][:epno]
      end.complete?
    end
  end

  def method_missing(method, *args)
    maintain_rate_limit
    @client ||= make_client
    @client.__send__(method, *args)
  end

  def respond_to_missing?(method, *)
    @client.respond_to?(method) || super
  end

  private

  def make_client
    params = %i[host port localport user pass nat].map { |k| @options[k] }
    logger = Loggers::UDPClient
    logger.instance_eval("def proto(v = '') ; self.debug v ; end", __FILE__, __LINE__)
    Net::AniDBUDP.new(*params, logger).tap(&:connect)
  end

  def update_mylist_with(info)
    Loggers::PostProcessor.debug "adding #{info.inspect} to mylist"
    mylist_add(info[:fid])
  end

  def retrieve_show_details(aid)
    @cache["anime_#{aid}"] ||= anime(aid)
  end

  def fetch_mylist_data(aid, episodes)
    @cache["mylist_#{aid}"] ||= create_mylist_data(aid, episodes)
  end

  def fetch_episode_no(eid)
    @cache["episode_#{eid}"] ||= episode(eid)[:episode][:epno]
  end

  def create_mylist_data(aid, episodes)
    mylist_hash = mylist_by_aid(aid)[:mylist]
    mylist_hash[:epno] = fetch_episode_no(mylist_hash[:eid]) if mylist_hash[:single_episode]
    MylistData.new(episodes.to_i, mylist_hash)
  end

  def identify_file(name, size, ed2k)
    search_file(name, size, ed2k).tap do |info|
      @cache["episode_#{info[:file][:eid]}"] = info[:anime][:epno] if info
      Loggers::PostProcessor.debug "file #{name} identified as #{info.inspect}"
    end
  end

  def maintain_rate_limit
    diff = Time.now - @now if @now
    sleep 3 - diff if diff && diff < 3
    @now = Time.now
  end
end
