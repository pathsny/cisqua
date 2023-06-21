RSpec::Matchers.define :be_equivalent_to do |expected|
  match do |actual|
    (expected <=> actual) == 0
  end
end

describe Source do
  it 'only allows valid sources' do
    expect { Source.new('foo') }.to raise_error(Invariant::AssertionError)
  end

  it 'does not rank unknown as better or worse' do
    expect(Source::UNKNOWN).to be_equivalent_to Source::CAMCORDER
    expect(Source::BLU_RAY).to be_equivalent_to Source::UNKNOWN
  end

  it 'ranks things of different classes as better or worse' do
    expect(Source::BLU_RAY).to be > Source::CAMCORDER
    expect(Source::DVD).to be > Source::WWW
  end

  it 'does not ranks things of the same class as better or worse' do
    expect(Source::TV).to be_equivalent_to Source::DTV
    expect(Source::TV).to be_equivalent_to Source::WWW
  end
end

describe Quality do
  it 'only allows valid qualities' do
    expect { Quality.new('foo') }.to raise_error(Invariant::AssertionError)
  end

  it 'ranks things of different qualities as better or worse' do
    expect(Quality::MED).to be > Quality::LOW
    expect(Quality::HIGH).to be < Quality::VERY_HIGH
  end
end

describe VideoResolution do
  it 'only allows valid resolutions' do
    expect { VideoResolution.new('foo') }.to raise_error(Invariant::AssertionError)
  end

  it 'ranks resolutions as better if width and/or height is better' do
    expect(VideoResolution.new('1280x720')).to be > VideoResolution.new('640x480')
    expect(VideoResolution.new('1280x720')).to be < VideoResolution.new('1920x1080')
  end

  it 'ranks resolutions as equal if width and height move in opposite directions' do
    expect(VideoResolution.new('800x448')).to be_equivalent_to VideoResolution.new('720x576')
  end
end

describe FileQuality do
  let(:common_info) { { quality: 'high', source: 'www', video_resolution: '1280x720', version: 2 } }

  context 'when sources are equivalent' do
    it 'ranks a higher quality over a lower quality, all else being equal' do
      expect(FileQuality.new(common_info)).to be > FileQuality.new(common_info.merge(quality: 'med'))
      expect(FileQuality.new(common_info)).to be < FileQuality.new(common_info.merge(quality: 'very high'))
    end

    it 'ranks a higher version over a lower version, all else being equal' do
      expect(FileQuality.new(common_info)).to be > FileQuality.new(common_info.merge(version: 1))
      expect(FileQuality.new(common_info)).to be < FileQuality.new(common_info.merge(version: 3))
    end

    it 'ranks a higher resolution over a lower resolution, all else being equal' do
      expect(FileQuality.new(common_info)).to be > FileQuality.new(common_info.merge(video_resolution: '640x480'))
      expect(FileQuality.new(common_info)).to be < FileQuality.new(common_info.merge(video_resolution: '1920x1080'))
    end

    it 'ranks one file quality over another if resolution, version and quality all improve or stay the same' do
      expect(FileQuality.new(common_info)).to be < FileQuality.new(common_info.merge(video_resolution: '1920x1080',
                                                                                     version: 3))
      expect(FileQuality.new(common_info)).to be > FileQuality.new(common_info.merge(video_resolution: '640x480',
                                                                                     quality: 'med'))
      expect(FileQuality.new(common_info)).to be > FileQuality.new(common_info.merge(version: 1, quality: 'med'))
      expect(FileQuality.new(common_info)).to be < FileQuality.new(common_info.merge(video_resolution: '1920x1080',
                                                                                     version: 3, quality: 'very high'))
    end

    it 'ranks as equal file qualities where resolution, version and quality move in different directions' do
      expect(FileQuality.new(common_info)).to be_equivalent_to FileQuality.new(common_info.merge(
                                                                                 video_resolution: '1920x1080', version: 1
                                                                               ))
    end

    it 'remains true for sources that are not equal but of the same score' do
      expect(FileQuality.new(common_info)).to be > FileQuality.new(common_info.merge(quality: 'med',
                                                                                     source: 'HKDVD'))
    end
  end

  context 'when sources are not equivalent' do
    it 'ranks a higher source over a lower source, all else being equal' do
      expect(FileQuality.new(common_info)).to be > FileQuality.new(common_info.merge(source: 'VHS'))
      expect(FileQuality.new(common_info)).to be < FileQuality.new(common_info.merge(source: 'Blu-ray'))
    end

    it 'ranks one file quality as better than another if resolution and/or quality move the same way' do
      expect(FileQuality.new(common_info)).to be > FileQuality.new(common_info.merge(source: 'VHS',
                                                                                     video_resolution: '640x480'))
      expect(FileQuality.new(common_info)).to be < FileQuality.new(common_info.merge(source: 'Blu-ray',
                                                                                     quality: 'very high'))
    end

    it 'ranks as equal file qualities where resolution and/or quality move in the opposite direction of source' do
      expect(FileQuality.new(common_info)).to be_equivalent_to FileQuality.new(common_info.merge(source: 'VHS',
                                                                                                 video_resolution: '1920x1080'))
      expect(FileQuality.new(common_info)).to be_equivalent_to FileQuality.new(common_info.merge(source: 'Blu-ray',
                                                                                                 quality: 'low'))
      expect(FileQuality.new(common_info)).to be_equivalent_to FileQuality.new(common_info.merge(source: 'Blu-ray',
                                                                                                 quality: 'low', video_resolution: '1920x1080'))
    end

    it 'ignores version' do
      expect(FileQuality.new(common_info)).to be > FileQuality.new(common_info.merge(source: 'VHS', version: 3))
      expect(FileQuality.new(common_info)).to be < FileQuality.new(common_info.merge(source: 'Blu-ray',
                                                                                     version: 1))
    end
  end
end
