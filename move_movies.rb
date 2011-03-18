require 'rubygems'
require 'fileutils'

abort "move_movies <source> <destination>" unless ARGV.length == 2
source = ARGV.first
files = Dir["#{source}/**/*Complete Movie.*"].entries + Dir["#{source}/**/*Part * of *.*"].entries
files.map{|f| File.dirname(f)}.uniq.each {|d| FileUtils.mv d, "#{ARGV[1]}/#{File.basename(d)}"}