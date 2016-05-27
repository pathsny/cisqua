require 'rest_client'
require 'nokogiri'
require 'slowweb'

SlowWeb.limit('anidb.net', 1, 2)

class AnidbResourceFetcher
  class << self
    def data(aid)
      get_file "#{aid}.xml" do 
        download_data(aid).tap { |res| raise "Banned from anidb" if res == "<error>Banned</error>" }
      end  
    end

    def thumb(aid)
      get_thumb_file(aid) do
        data_file = self.data(aid)
        File.open(data_file, 'r') do |f|
          xml = Nokogiri::XML(f)
          xml.at_xpath('/anime/picture').content
        end
      end  
    end  


    private
    def get_file(name)
      file_path = File.join(Web_dir, '../data/http_anime_info_cache', name)
      return file_path if File.exist?(file_path)
      lock_path = File.join(Web_dir, '../data/http_anime_info_cache', 'lock', name) 
      begin
        lock_file = File.open(lock_path, File::RDWR|File::CREAT)
        lock_file.flock(File::LOCK_EX)
        return file_path if File.exist?(file_path)
        data = yield
        file = File.open(file_path, 'wb') do |output|
          output.write data
        end
        return file_path  
      ensure
        lock_file.close unless lock_file.nil?
      end  
    end

    def get_thumb_file(aid)
      get_file("#{aid}-thumb.jpg") do
        pic_file = yield
        RestClient.get "http://img7.anidb.net/pics/anime/thumbs/50x65/#{pic_file}-thumb.jpg"  
      end      
    end

    def download_data(aid)
      RestClient.get "http://api.anidb.net:9001/httpapi?client=misakatron&clientver=1&protover=1&request=anime&aid=#{aid}" 
    end
  end  
end  