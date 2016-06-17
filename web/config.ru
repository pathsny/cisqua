# config.ru (run with rackup)
require_relative 'app.rb'
require_relative 'middleware/log_tailer'

use LogTailer
run App