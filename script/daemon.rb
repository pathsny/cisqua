#This is a daemon that can be deploy for production. Check out the helper webserver_rc.d 
#script that can be used in tandem

require 'rubygems'
require 'daemons'
main_file = File.expand_path(File.join(
  File.dirname(__FILE__), 
  '..', 
  'web',
  'main.rb'
))

def custom_show_status(app)
  # Display the default status information
  app.default_show_status

  puts
  puts "PS information"
  system("ps -p #{app.pid.pid.to_s}")
end  

Daemons.run(main_file, { show_status_callback: :custom_show_status })