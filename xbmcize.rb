#renames all specials with xbmc metadata

require 'rubygems'
require 'fileutils'
require File.expand_path('../lib/libs', __FILE__)

abort "xbmcize <path>" unless ARGV.length == 1

def transform(type)
  type == 'S' ? 0 : 100 + type.bytes.first - 64
end
#  

location = ARGV.first
files = Dir["#{location}/**/* - episode [A-Z]*.*"].entries
files.reject{|f| f.match /.*\[\(XS-[^\)]*\)\]/ }.tap{|fs| p fs.inspect}.each do |file|
  begin
    extension = File.extname(file)
    new_name = file.gsub(/(.*episode )([A-Z])(\d+)(.*)#{extension}/) { "#{$1}#{$2}#{$3}#{$4} [(XS-#{transform($2)}-#{$3})]#{extension}" }
    FileUtils.mv file, new_name
    p "renamed #{file} to #{new_name}"
  rescue
    p "cannot process #{file} because #{$!}"
  end
end

