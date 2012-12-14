require File.expand_path('../spec_helper', __FILE__)
require File.expand_path('../../lib/mylist_data', __FILE__)

describe MylistData do
  it 'provides a list of the normal episodes' do
    data = MylistData.new 12, :title=>"Binchou-tan", :unknown_ep_list=>"", :episodes=>"12", :hdd_ep_list=>"1-5,7,9,11", :deleted_ep_list=>"", :cd_ep_list=>"", :single_episode => false
    data.normal_episodes.should match_array([1,2,3,4,5,7,9,11])
  end
  
  it 'generates a union of the unknown, hdd and cd eps' do
    data = MylistData.new 12, :title=>"Binchou-tan", :unknown_ep_list=>"9", :episodes=>"12", :hdd_ep_list=>"1-5,7", :deleted_ep_list=>"", :cd_ep_list=>"2", :single_episode => false
    data.normal_episodes.should match_array([1,2,3,4,5,7,9])
  end
  
  it 'generates a union that also contains special episodes' do
    data = MylistData.new 12, :title=>"Binchou-tan", :unknown_ep_list=>"", :episodes=>"12", :hdd_ep_list=>"1-5,7,9,11", :deleted_ep_list=>"", :cd_ep_list=>"C1-C3,T01", :single_episode => false
    data.normal_episodes.should match_array([1,2,3,4,5,7,9,11])
    data.special_episodes.should match_array(["C1", "C2", "C3", "T01"])
  end    
  
  it 'allows you to add an episode but maintains only a single copy' do
    data = MylistData.new 12, :title=>"Binchou-tan", :unknown_ep_list=>"", :episodes=>"12", :hdd_ep_list=>"1-5,7,9,11", :deleted_ep_list=>"", :cd_ep_list=>"C1-C3,T01", :single_episode => false
    data.add "5"
    data.normal_episodes.should match_array([1,2,3,4,5,7,9,11])
    data.add 5
    data.normal_episodes.should match_array([1,2,3,4,5,7,9,11])
    data.add "6"
    data.normal_episodes.should match_array([1,2,3,4,5,6,7,9,11])
    data.add 8
    data.normal_episodes.should match_array([1,2,3,4,5,6,7,8,9,11])
    data.add "T01"
    data.special_episodes.should match_array(["C1", "C2", "C3", "T01"])
    data.add "T02"
    data.special_episodes.should match_array(["C1", "C2", "C3", "T01", "T02"])
  end
  
  it 'reports if the show is complete (comparing episode count with the number of normal episodes)' do
    data = MylistData.new 12, :title=>"Binchou-tan", :unknown_ep_list=>"", :episodes=>"12", :hdd_ep_list=>"1-5,7,9,11", :deleted_ep_list=>"", :cd_ep_list=>"C1-C3,T01", :single_episode => false
    data.should_not be_complete
    [6, 8, "10", 12].each {|k| data.add k}
    data.should be_complete
  end
  
  it 'allows for 0 prefixed episodes' do
    data = MylistData.new 12, :title=>"Binchou-tan", :unknown_ep_list=>"", :episodes=>"12", :hdd_ep_list=>"1-5,7,9,11", :deleted_ep_list=>"", :cd_ep_list=>"C1-C3,T01", :single_episode => false
    data.add("01")
    data.normal_episodes.should match_array([1,2,3,4,5,7,9,11])
    data.add("06")
    data.normal_episodes.should match_array([1,2,3,4,5,6,7,9,11])
  end  
  
  it 'understands the data when you have a single episode of a 1 episode show' do
    data = MylistData.new 1, :lid=>51718530, :fid=>"43501", :eid=>"16368", :aid=>"1516", :gid=>"183", :date=>"1219466009", :state=>"1", :epno => "01", :viewdate=>"0", :storage=>"", :source=>"", :other=>"", :filestate=>"0", :single_episode => true
    data.should be_complete
    data.add(1)
    data.normal_episodes.should match_array([1])
    data.special_episodes.should match_array([])
    data.should be_complete
  end
  
  it 'understands the data when you have a single episode of a multi episode show' do  
    data = MylistData.new 12, :lid=>51718530, :fid=>"43501", :eid=>"16368", :aid=>"1516", :gid=>"183", :date=>"1219466009", :state=>"1", :epno => "01", :viewdate=>"0", :storage=>"", :source=>"", :other=>"", :filestate=>"0", :single_episode => true
    data.should_not be_complete 
  end      
end  