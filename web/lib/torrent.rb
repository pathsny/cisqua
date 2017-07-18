require 'trans-api'

CONFIG = { 
  host: '10.0.0.35', 
  port: 9091, 
  path: '/transmission/rpc', 
}

Trans::Api::Client.config = CONFIG

class Torrent
  class << self
    def download(feed_item)
      client = Trans::Api::Client.new
      res = client.connect.torrent_add({
        'download-dir' => '/media/Incoming/Anime/',
        :filename => feed_item.url,
      })
      feed_item.downloaded_at = DateTime.now
      feed_item.save
    end  
  end

  def test(config)
    puts "testing #{config}"
    # res = Trans::Api::Connect.new config
    # puts res.inspect
    # res
  end  
end
