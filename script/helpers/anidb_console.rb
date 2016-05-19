# console for debugging
require 'yaml'
Options = YAML.load_file File.expand_path('../../../data/options.yml', __FILE__)
require File.expand_path('../../../lib/libs', __FILE__)
Client = Net::AniDBUDP.new(*([:host, :port, :localport, :user, :pass, :nat].map{|k| Options[:anidb][k]}))
