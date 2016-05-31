require_from_root 'web/lib/feed_processor'
require 'concurrent-edge'

describe FeedProcessor do
  let(:dbs) do {} end

  before(:all) { 
    Model::ModelDB = stub() 
    module Feedjira
      module Feed
      end
    end    
  }
  after(:all) { Model.send(:remove_const, :ModelDB) }

  context :update_show do
    before :each do
      spec_this = self
      Model::ModelDB.define_singleton_method(:get_db) { |name, &b|
        spec_this.dbs[name] = {} unless spec_this.dbs.has_key?(name)
        b.call(spec_this.dbs[name]) 
      }
      FeedProcessor.stubs(:is_valid?).returns(true)
      FeedProcessor.instance_variable_set(
        :@fixed_pool_executor, 
        Concurrent::ImmediateExecutor.new,
      )
      Concurrent::Options.stubs(:executor).returns(
        Concurrent::SingleThreadExecutor.new
      )
      FeedProcessor.stubs(:update_show).returns(Concurrent.succeeded_future(true))
      Show.create(10, "Jojo", "http://foo.bar/jojo", true).save
      Show.create(11, "Snk", "http://foo.bar/snk", false).save
      FeedProcessor.unstub(:update_show)
    end

    let(:initial_feed_entries) do 
      [stub(
        :entry_id => "http://www.nyaa.se/?page=view&tid=805166",
        :url => "http://www.nyaa.se/?page=download&tid=805166",
        :title => "[HorribleSubs] Kabaneri of the Iron Fortress - 07 [480p].mkv",
        :published => Time.parse("2016-05-27 01:13:02 UTC"),
        :summary => "461 seeder(s), 31 leecher(s), 8509 download(s) - 221.7 MiB - Trusted",
      ),
      stub(
        :entry_id => "http://www.nyaa.se/?page=view&tid=815235",
        :url => "http://www.nyaa.se/?page=download&tid=815235",
        :title => "[HorribleSubs] Kabaneri of the Iron Fortress - 07 [1080p].mkv",
        :published => Time.parse("2016-05-27 00:40:07 UTC"),
        :summary => "1131 seeder(s), 57 leecher(s), 17932 download(s) - 751.2 MiB - Trusted",
      )]
    end

    let(:initial_feed_stub) do
      stub(:entries => initial_feed_entries)
    end  

    let(:additional_feed_stub) do
      stub(:entries => 
        initial_feed_entries.push(stub(
          :entry_id => "http://www.nyaa.se/?page=view&tid=815212",
          :url => "http://www.nyaa.se/?page=download&tid=815212",
          :title => "[HorribleSubs] Kabaneri of the Iron Fortress - 07 [720p].mkv",
          :published => Time.parse("2016-05-26 21:17:27 UTC"),
          :summary => "2536 seeder(s), 88 leecher(s), 45113 download(s) - 392 MiB - Trusted",
        ))
      )   
    end

    it "fetches using the feed url" do
      Feedjira::Feed.expects(:fetch_and_parse).with do |feed_url| 
        feed_url == "http://foo.bar/jojo"
      end.returns(initial_feed_stub)
      FeedProcessor.update_show(10).wait  
    end

    it "sets the show to is_updating_feed_items while is_updating_feed_items" do
      Feedjira::Feed.stubs(:fetch_and_parse).with do |feed_url|
        expect(Show.get(10).is_updating_feed_items).to be(true) 
      end.returns(initial_feed_stub)
      FeedProcessor.update_show(10).wait  
    end

    it "unsets is_updating_feed_items for the show after is_updating_feed_items" do
      Feedjira::Feed.stubs(:fetch_and_parse).returns(initial_feed_stub)
      FeedProcessor.update_show(10).wait
      expect(Show.get(10).is_updating_feed_items).to be(false)   
    end

    it "unsets is_updating_feed_items for the show after is_updating_feed_items even in case of error" do
      Feedjira::Feed.stubs(:fetch_and_parse).with do |f|
        raise "hell"
      end.returns(initial_feed_stub)
      FeedProcessor.update_show(10).wait
      expect(Show.get(10).is_updating_feed_items).to be(false)   
    end

    context "after updating show" do
      before :each do
        Feedjira::Feed.stubs(:fetch_and_parse).returns(initial_feed_stub)
        Timecop.freeze(DateTime.parse("2016-05-28 10:09:22")) do
          FeedProcessor.update_show(10).wait
        end  
      end

      it "creates feed_items for the show" do
        feed_items = Model.get_collection(:feed_item, 10).all 
        expect(feed_items.count).to be(2)
        expect(feed_items.map(&:id)).to match_array([
          "http://www.nyaa.se/?page=view&tid=805166",
          "http://www.nyaa.se/?page=view&tid=815235"
        ])
        feed_items = Show.get(10).feed.all 
        expect(feed_items.count).to be(2)
        expect(feed_items.map(&:id)).to match_array([
          "http://www.nyaa.se/?page=view&tid=805166",
          "http://www.nyaa.se/?page=view&tid=815235"
        ])
      end

      it "does not touch other shows" do
        expect(Show.get(11).feed.all).to be_empty 
      end

      it "updates the last_checked_at and latest_feed_item_added_at" do
        expect(Show.get(10).last_checked_at).to eq(DateTime.parse("2016-05-28 10:09:22"))
        expect(Show.get(10).latest_feed_item_added_at).to eq(DateTime.parse("2016-05-28 10:09:22"))
        Timecop.freeze(DateTime.parse("2016-06-15 19:32:00")) do
          FeedProcessor.update_show(10).wait
        end  
        expect(Show.get(10).last_checked_at).to eq(DateTime.parse("2016-06-15 19:32:00"))
        expect(Show.get(10).latest_feed_item_added_at).to eq(DateTime.parse("2016-05-28 10:09:22"))
      end  

      it "adds additional feed_items when updating the show gets a newer feed" do
        Feedjira::Feed.stubs(:fetch_and_parse).returns(additional_feed_stub)
        Timecop.freeze(DateTime.parse("2016-8-12 05:05:05")) do
          FeedProcessor.update_show(10).wait
        end  
        feed_items = Model.get_collection(:feed_item, 10).all
        expect(feed_items.count).to be(3) 
        expect(feed_items.map(&:id)).to match_array([
          "http://www.nyaa.se/?page=view&tid=805166",
          "http://www.nyaa.se/?page=view&tid=815235",
          "http://www.nyaa.se/?page=view&tid=815212"
        ])
        expect(Show.get(10).last_checked_at).to eq(DateTime.parse("2016-8-12 05:05:05"))
        expect(Show.get(10).latest_feed_item_added_at).to eq(DateTime.parse("2016-8-12 05:05:05"))
      end  
    end  
  end  
end  