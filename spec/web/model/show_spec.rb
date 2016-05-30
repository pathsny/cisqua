require_from_root 'web/model/show'

describe Show do
  let(:db) do {} end  

  let (:new_show) { Show.create(15, "Escaflowne", "http://foo.bar/esca", false) }
  let (:duplicate_show) { show = Show.create(25, "foo", "bar", false) }

  before(:all) { Model::ModelDB = stub() }
  after(:all) { Model.send(:remove_const, :ModelDB) }
  
  before :each do
    spec_this = self
    Model::ModelDB.define_singleton_method(:get_db) { |name, &b|
      spec_this.expect(name).to spec_this.eq('shows') 
      b.call(spec_this.db) 
    }
    FeedProcessor.stubs(:is_valid?).returns(true)
    Show.create(10, "Jojo", "http://foo.bar/jojo", true).save
    Show.create(12, "Akira", "http://foo.bar/akira", true).save
    Show.create(17, "Gits", "http://foo.bar/gits", true).save
    Show.create(25, "Snk", "http://foo.bar/snk", true).save
  end

  context :all do
    it "returns all items" do
      expect(Show.all.count).to be(4)
      expect(Show.all.map(&:id)).to match_array([10, 12, 17, 25])
      expect(Show.all.map(&:name)).to match_array(["Akira", "Gits", "Jojo", "Snk"])
    end

    it "returns items that are not new" do
      expect(Show.all.map(&:new_record?).none?).to be(true)
    end

    it "returns items that all have a created at and updated at" do
      expect(Show.all.map(&:created_at).map(&:nil?).none?).to be(true)
      expect(Show.all.map(&:updated_at).map(&:nil?).none?).to be(true)
    end
  end

  context :get do
    it "returns an item from the db" do
      expect(Show.get(12).name).to eq("Akira")
    end

    it "throws on a missing item" do
      expect{Show.get(15)}.to raise_error
    end
  end

  it "returns status for an item in the db when calling exists?" do
    expect(Show.exists?(12)).to be(true)
    expect(Show.exists?(15)).to be(false)
  end

  it "cannot be created with new" do
    expect {ShowInstance.new}.to raise_error
  end
  
  context :create do
    it "is new" do
      expect(new_show).to be_new_record
    end

    it "has a nil created_at and updated_at" do
      expect(new_show.created_at).to be_nil
      expect(new_show.updated_at).to be_nil
    end

    it "has a version which is current" do
      expect(new_show.version).to eq(ShowInstance.current_version)
    end
  end

  context :has_instance_in_db? do
    it "is true for an item in the db" do
      expect(Show.all.sample.has_instance_in_db?).to be(true)
      expect(Show.get(17).has_instance_in_db?).to be(true)
    end

    it "is true for a new item with an id in the db" do 
      expect(duplicate_show.has_instance_in_db?).to be(true)
    end

    it "is false for an entirely new item" do
      expect(new_show.has_instance_in_db?).to be(false)
    end 
  end

  context :is_valid? do
    it "is valid if well formed" do
      expect(new_show).to be_valid
    end
    
    it "is invalid if it is a duplicate" do
      expect(duplicate_show).to_not be_valid
      expect(duplicate_show.errors).to be_eql({:id => ["show must be unique"]})
    end

    it "is valid for an existing db item" do
      expect(Show.get(10)).to be_valid
    end  

    it "is invalid if the feed_url cannot be parsed" do
      FeedProcessor.unstub(:is_valid?)
      expect(new_show).to_not be_valid
      expect(new_show.errors).to be_eql({:feed_url => ["Invalid feed url"]})
    end  
  end

  context :save do
    it "fails if it is invalid" do
      expect { duplicate_show.save }.to raise_error
      expect(duplicate_show).to be_new_record
      expect(duplicate_show.created_at).to be_nil
      expect(duplicate_show.updated_at).to be_nil
    end

    it "returns the record" do
      expect(new_show.save).to be(new_show)
    end  

    it "creates a record which is not new" do
      expect(new_show.save).to_not be_new_record
    end

    it "sets created_at and updated_at when saving a new record" do
      Timecop.freeze(DateTime.parse("2016-05-28 10:09:22")) do
        new_show.save
        expect(new_show.created_at).to eq(DateTime.parse("2016-05-28 10:09:22"))
        expect(new_show.updated_at).to eq(DateTime.parse("2016-05-28 10:09:22"))
      end  
    end

    it "can be retrieved from the db" do
      new_show.save
      expect(Show.get(15).name).to eq("Escaflowne")
      expect(Show.all.map(&:id)).to include(15)
    end

    it "only sets updated at when saving an existing record" do
      Timecop.freeze(DateTime.parse("2016-05-28 10:09:22")) do
        new_show.save
      end  
      Timecop.freeze(DateTime.parse("2016-06-15 19:32:00")) do
        new_show.save
      end  
      expect(new_show.created_at).to eq(DateTime.parse("2016-05-28 10:09:22"))
      expect(new_show.updated_at).to eq(DateTime.parse("2016-06-15 19:32:00"))
    end

    it "calls on_save with was_new being true and all fields when newly created" do
      new_show.expects(:on_save).with(true, {})
      new_show.last_checked_at = DateTime.now
      new_show.save
    end

    it "calls on_save with was_new being false if saved again" do
      new_show.expects(:on_save).with(true, {})
      new_show.save
      new_show.expects(:on_save).with(false, {})
      new_show.save
    end

    it "calls on_save with the old values of dirty fields if saved again" do
      new_show.expects(:on_save).with(true, {})
      new_show.save

      new_show.auto_fetch = true
      new_show.expects(:on_save).with(false, {auto_fetch: false})
      new_show.save

      new_show.auto_fetch = true
      new_show.last_checked_at = DateTime.parse("2016-06-15 19:32:00")
      new_show.expects(:on_save).with(false, {last_checked_at: nil})
      new_show.save

      new_show.auto_fetch = false
      new_show.last_checked_at = DateTime.parse("2016-05-28 10:09:22")
      new_show.expects(:on_save).with(false, {
        auto_fetch: true,
        last_checked_at: DateTime.parse("2016-06-15 19:32:00"),
      })
      new_show.save
    end  

    it "calls on_save with was_new being false if retrieved from db" do
      show = Show.get(10)
      show.auto_fetch = false
      show.expects(:on_save).with(false, {auto_fetch: true})
      show.save
    end  
  end

  context :destroy! do
    it "removes a record from the db" do
      Show.get(12).destroy!
      expect(Show.exists?(12)).to be(false)
      expect(Show.all.map(&:id)).to_not include(12)
    end

    it "returns the record" do
      show = Show.get(12)
      expect(show.destroy!).to be(show)
    end

    it "calls on_destroy" do
      show = Show.get(10)
      show.expects(:on_destroy)
      show.destroy!
    end  
  end

  context :marshal do
    it "only marshals required fields" do
      show = Show.get(10)
      expect(show.marshal_dump).to eq([
        show.version,
        'shows', 
        show.created_at,
        show.updated_at,
        show.id,
        show.name,
        show.feed_url,
        show.auto_fetch,
        show.last_checked_at,
      ]);
    end

    it "can unmarshal itself and create a record that is not new" do
      show = ShowInstance.send(:allocate)
      show.marshal_load(new_show.marshal_dump)
      imp_values = [:version, :id, :name, :feed_url, :auto_fetch, :created_at, :updated_at]
      expect(imp_values.map{|v| show.send(v)}).to eq(
        imp_values.map{|v| new_show.send(v)}
      )
      expect(show).to_not be_new_record
    end  
  end

  context :collection do
    it "deletes the db if destroy! is called on the collection" do
      Model::ModelDB.expects(:destroy).with('shows')
      Show.destroy!
    end  
  end  
end     