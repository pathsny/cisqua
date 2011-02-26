require File.expand_path('../../net/ranidb', __FILE__)

class Anidb
  def initialize(options)
    @client = Net::AniDBUDP.new(*([:host, :port, :localport, :user, :pass, :nat].map{|k| options[k]}))
  end
  
  def connect
    @client.connect
  end
  
  def maintain_rate_limit
    diff = Time.now - @now if @now
    sleep 2 - diff if diff && diff < 2
    @now = Time.now
  end  
  
  def method_missing(method, *args)
    maintain_rate_limit
    @client.__send__(method, *args)
  end
end        