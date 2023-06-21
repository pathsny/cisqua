# renames all specials with xbmc metadata

require 'rubygems'
require 'fileutils'
require File.expand_path('lib/libs', __dir__)

abort 'xbmcize <path>' unless ARGV.length == 1

def transform(type)
  type == 'S' ? 0 : 100 + type.bytes.first - 64
end

location = ARGV.first
files = Dir["#{location}/**/* - episode [A-Z]*.*"].entries
files.reject { |f| f.match(/.*\[\(XS-[^)]*\)\]/) }.tap { |fs| p fs.inspect }.each do |file|
  extension = File.extname(file)
  new_name = file.gsub(/(.*episode )([A-Z])(\d+)(.*)#{extension}/) do
    "#{Regexp.last_match(1)}#{Regexp.last_match(2)}#{Regexp.last_match(3)}#{Regexp.last_match(4)} [(XS-#{transform(Regexp.last_match(2))}-#{Regexp.last_match(3)})]#{extension}"
  end
  FileUtils.mv file, new_name
  p "renamed #{file} to #{new_name}"
rescue StandardError
  p "cannot process #{file} because #{$!}"
end
