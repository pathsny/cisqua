#  this method should return a path where files should be stored inside the destination directory and 
# the name that an identified file should take.
# As a sample, the given file uses the romanji name of the anime as the folder
# and the file is written as anime_name - episode <number> [groupname] and movie files are stored as
# anime_name - Complete Movie or anime_name - Part 1 of 3.
# here is a sample of the "info" you will get if you want to change the name format.

# {:fid=>271926, :file=>{:length=>"1778", :quality=>"high", :video_resolution=>"640x480", :source=>"LD", :sub_language=>"none", :gid=>"0", :dub_language=>"japanese", :eid=>"26772", :aid=>"1179"}, :anime=>{:type=>"OVA", :ep_romaji_name=>"", :highest_episode_number=>"2", :group_name=>"raw/unknown", :english_name=>"", :group_short_name=>"raw", :romaji_name=>"Bounty Dog: Getsumen no Ibu", :year=>"1994-1994", :epno=>"1", :ep_english_name=>"Code 1"}}

def generate_name(info)
  anime = info[:anime]
  name = anime[:romaji_name]
  part = movie?(anime) ? anime[:ep_english_name] : "episode #{anime[:epno]}"
  [anime[:romaji_name], "#{name} - #{part}#{group_name(anime)}#{metadata_for_xbmc(anime)}"]  
end

def group_name(anime)
  g = anime[:group_short_name]
  g == 'raw' ? nil : " [#{g}]"
end

def movie?(anime)
  anime[:type] == "Movie"
end

def char_value(char)
  char == 'S' ? 0 : 100 + char.upcase.bytes.first - 64
end  

def special_metadata(epno)
  result = /^([A-Z])?(\d+)$/.match epno
  raise "unknown" unless result
  result[1] && " [(XS-#{char_value result[1]}-#{result[2]})]"
end    

def metadata_for_xbmc(anime)
  epno = anime[:epno]
  special_metadata(epno) || (movie?(anime) ? " [(X-#{epno})]" : "")
end
     