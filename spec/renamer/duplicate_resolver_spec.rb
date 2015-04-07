describe Renamer::DuplicateResolver do
  let(:common_file) {{:aid => '10206', :eid => '158897', :gid => '11193'}}

  def resolve(current, duplicates)
    Renamer::DuplicateResolver.resolve(current, duplicates).tap do |resolved|
      expect(resolved[:selected]).to(eq(current)) if resolved[:keep_current]
    end  
  end

  def make_fid
    Faker::Number.number(5).to_i
  end          

  def make_item(file_params, fid = nil)
    info = {:fid => fid || make_fid, :anime => {}, :file => common_file.merge(file_params)}
    WorkItem.new(Faker::Lorem.sentence, info)
  end

  def clone_item(item)
    make_item(item.info[:file], item.info[:fid])
  end

  def wierdly_similar_item(item)
    make_item(item.info[:file])
  end  

  let(:sources) { Renamer::DuplicateResolver::Sources }
  let(:quality) { Renamer::DuplicateResolver::Quality }
  let(:current_info) { {:version => 2, :source => 'www', :quality => 'high', :video_resolution => '1280x720' } }
  let(:current) { make_item(current_info) }
  let(:clone_1) { clone_item(current) }
  let(:wierdly_similar) { wierdly_similar_item(current) }
  let(:version_1) { make_item(current_info.merge(:version => 1))}
  let(:version_3) { make_item(current_info.merge(:version => 3))}
  let(:camcorder) { make_item(current_info.merge(:source => 'camcorder')) }
  let(:vhs_with_version_3) { make_item(current_info.merge(:source => 'VHS', :version => 3))}
  let(:hdtv_with_eyecancer) { make_item(current_info.merge(:source => 'HDTV', :quality => 'eyecancer')) }
  let(:vcd_with_very_high) { make_item(current_info.merge(:source => 'VCD', :quality => 'very high')) } 
  let(:blu_ray) { make_item(current_info.merge(:source => 'Blu-ray')) }

  context "when all the dups are clones of the current" do
    let(:clone_2) { clone_item(current) }
    let(:resolved) { resolve(current, [clone_2, clone_1])}
    it { expect(resolved[:keep_current]).to be true }
    it("junks the clones") { expect(resolved[:junk]).to match_array([clone_1, clone_2]) }
    it("marks no dups") { expect(resolved[:dups]).to eq([])}
  end

  context "when the dups are worse than the current item" do
    let(:resolved) { resolve(current, [camcorder, version_1, vhs_with_version_3])} 

    it "keeps current" do
      expect(resolve(current, [version_1])[:keep_current]).to be true 
      expect(resolve(current, [camcorder])[:keep_current]).to be true 
      expect(resolved[:keep_current]).to be true 
    end

    it "rejects the worse dups" do
      v1_clone = clone_item(version_1)
      expect(resolve(current, [version_1, v1_clone])[:junk]).to match([v1_clone, version_1])
      expect(resolved[:junk]).to match_array([camcorder, version_1, vhs_with_version_3])
    end

    it("marks no dups") { expect(resolved[:dups]).to eq([])}
  end

  context "when there are dups that are not worse than the current item" do
    let(:resolved) { resolve(current, [version_1, clone_1, hdtv_with_eyecancer, vcd_with_very_high, wierdly_similar])}

    it "keeps current" do
      expect(resolve(current, [hdtv_with_eyecancer])[:keep_current]).to be true
      expect(resolved[:keep_current]).to be true
    end

    it "junks items that are worse than current" do
      expect(resolved[:junk]).to match_array([version_1, clone_1])
    end  

    it "marks as dup, those items which are not worse than the current item" do
      expect(resolved[:dups]).to match_array([hdtv_with_eyecancer, vcd_with_very_high, wierdly_similar])
    end
  end

  context "when there are dups that are better than the current item" do
    let(:resolved) { resolve(current, [version_1, clone_1, hdtv_with_eyecancer, wierdly_similar, version_3, blu_ray]) }

    it "does not keep current" do
      expect(resolve(current, [version_3])[:keep_current]).to be false
      expect(resolve(current, [blu_ray])[:keep_current]).to be false
      expect(resolved[:keep_current]).to be false
    end

    it "selects the best item when there is just one" do
      expect(resolved[:selected]).to eq(blu_ray)
    end

    it "junks items that are worse than the best item" do
      expect(resolved[:junk]).to match_array([version_1, clone_1, hdtv_with_eyecancer, wierdly_similar, version_3])
    end

    it "selects one best item if it has clones and junks the others" do
      blu_ray_clone = clone_item(blu_ray)
      resolved = resolve(current, [blu_ray_clone, blu_ray]) 
      expect(resolved[:keep_current]).to be false
      expect(resolved[:selected]).to be blu_ray_clone
      expect(resolved[:junk]).to match_array([blu_ray])
      expect(resolved[:dups]).to eq([])
    end

    it "selects one of the best items if there is more than one and dups the others" do
      resolved = resolve(current, [blu_ray, hdtv_with_eyecancer, vcd_with_very_high])
      expect(resolved[:keep_current]).to be false
      expect(resolved[:selected]).to be blu_ray
      expect(resolved[:junk]).to match_array([hdtv_with_eyecancer])
      expect(resolved[:dups]).to match_array([vcd_with_very_high])
    end
  end  
end
