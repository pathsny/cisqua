require 'yaml'
Options = YAML.load_file File.expand_path('../../options.yml', __FILE__)
require File.expand_path('../../net/ranidb', __FILE__)
Client = Net::AniDBUDP.new(*([:host, :port, :localport, :user, :pass, :nat].map{|k| Options[:anidb][k]}))
Client.connect 