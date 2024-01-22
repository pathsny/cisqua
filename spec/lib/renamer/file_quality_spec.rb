RSpec::Matchers.define :be_equivalent_to do |expected|
  match do |actual|
    (expected <=> actual).zero?
  end
end

def comparison_result(q1, q2)
  described_class.new(q1).compare_with_info(described_class.new(q2))
end

describe Cisqua::Renamer::Source do
  it 'only allows valid sources' do
    expect { described_class.new('foo') }.to raise_error(SolidAssert::AssertionFailedError)
  end

  it 'does not rank unknown as better or worse' do
    expect(described_class::UNKNOWN).to be_equivalent_to described_class::CAMCORDER
    expect(described_class::BLU_RAY).to be_equivalent_to described_class::UNKNOWN
  end

  it 'ranks things of different classes as better or worse' do
    expect(described_class::BLU_RAY).to be > described_class::CAMCORDER
    expect(described_class::DVD).to be > described_class::WWW
  end

  it 'does not ranks things of the same class as better or worse' do
    expect(described_class::TV).to be_equivalent_to described_class::DTV
    expect(described_class::TV).to be_equivalent_to described_class::WWW
  end
end

describe Cisqua::Renamer::Quality do
  it 'only allows valid qualities' do
    expect { described_class.new('foo') }.to raise_error(SolidAssert::AssertionFailedError)
  end

  it 'ranks things of different qualities as better or worse' do
    expect(described_class::MED).to be > described_class::LOW
    expect(described_class::HIGH).to be < described_class::VERY_HIGH
  end
end

describe Cisqua::Renamer::VideoResolution do
  it 'only allows valid resolutions' do
    expect { described_class.new('foo') }.to raise_error(SolidAssert::AssertionFailedError)
  end

  it 'ranks resolutions as better if width and/or height is better' do
    expect(described_class.new('1280x720')).to be > described_class.new('640x480')
    expect(described_class.new('1280x720')).to be < described_class.new('1920x1080')
  end

  it 'ranks resolutions as equal if width and height move in opposite directions' do
    expect(described_class.new('800x448')).to be_equivalent_to described_class.new('720x576')
  end
end

describe Cisqua::Renamer::FileQuality do
  let(:common_info) { { quality: 'high', source: 'www', video_resolution: '1280x720', version: 2 } }

  context 'when sources are equivalent' do
    it 'ranks a higher quality over a lower quality, all else being equal' do
      expect(described_class.new(common_info)).to be > described_class.new(
        common_info.merge(quality: 'med'),
      )
      expect(described_class.new(common_info)).to be < described_class.new(
        common_info.merge(quality: 'very high'),
      )
    end

    it 'ranks a higher version over a lower version, all else being equal' do
      expect(described_class.new(common_info)).to be > described_class.new(
        common_info.merge(version: 1),
      )
      expect(described_class.new(common_info)).to be < described_class.new(
        common_info.merge(version: 3),
      )
    end

    it 'ranks a higher resolution over a lower resolution, all else being equal' do
      expect(described_class.new(common_info)).to be > described_class.new(
        common_info.merge(video_resolution: '640x480'),
      )
      expect(described_class.new(common_info)).to be < described_class.new(
        common_info.merge(video_resolution: '1920x1080'),
      )
    end

    it 'ranks one file quality over another if resolution, version and quality all improve or stay the same' do
      expect(described_class.new(common_info)).to be < described_class.new(common_info.merge(
        video_resolution: '1920x1080',
        version: 3,
      ))
      expect(described_class.new(common_info)).to be > described_class.new(common_info.merge(
        video_resolution: '640x480',
        quality: 'med',
      ))
      expect(described_class.new(common_info)).to be > described_class.new(common_info.merge(
        version: 1,
        quality: 'med',
      ))
      expect(described_class.new(common_info)).to be < described_class.new(common_info.merge(
        video_resolution: '1920x1080',
        version: 3,
        quality: 'very high',
      ))
    end

    it 'ranks as equal file qualities where resolution, version and quality move in different directions' do
      expect(described_class.new(common_info)).to be_equivalent_to described_class.new(
        common_info.merge(video_resolution: '1920x1080', version: 1),
      )
    end

    it 'remains true for sources that are not equal but of the same score' do
      expect(described_class.new(common_info)).to be > described_class.new(
        common_info.merge(quality: 'med', source: 'HKDVD'),
      )
    end

    it 'returns information to understand the comparison result' do
      expect(comparison_result(
        common_info,
        common_info.merge(quality: 'med'),
      )).to eq(
        comp: 1,
        left: { quality: 'high' },
        right: { quality: 'med' },
      )
      expect(comparison_result(
        common_info,
        common_info.merge(version: 3),
      )).to eq(
        comp: -1,
        left: { version: '2' },
        right: { version: '3' },
      )
      expect(comparison_result(
        common_info,
        common_info.merge(
          video_resolution: '640x480',
          quality: 'med',
        ),
      )).to eq(
        comp: 1,
        left: { quality: 'high', video_resolution: '1280x720' },
        right: { quality: 'med', video_resolution: '640x480' },
      )
      expect(comparison_result(
        common_info,
        common_info,
      )).to eq(
        comp: 0,
        left: {},
        right: {},
      )
      expect(comparison_result(
        common_info,
        common_info.merge(video_resolution: '1920x1080', version: 1),
      )).to eq(
        comp: 0,
        left: { video_resolution: '1280x720', version: '2' },
        right: { video_resolution: '1920x1080', version: '1' },
      )
    end
  end

  context 'when sources are not equivalent' do
    it 'ranks a higher source over a lower source, all else being equal' do
      expect(described_class.new(common_info)).to be > described_class.new(
        common_info.merge(source: 'VHS'),
      )
      expect(described_class.new(common_info)).to be < described_class.new(
        common_info.merge(source: 'Blu-ray'),
      )
    end

    it 'ranks one file quality as better than another if resolution and/or quality move the same way' do
      expect(described_class.new(common_info)).to be > described_class.new(
        common_info.merge(source: 'VHS', video_resolution: '640x480'),
      )
      expect(described_class.new(common_info)).to be < described_class.new(
        common_info.merge(source: 'Blu-ray', quality: 'very high'),
      )
    end

    it 'ranks as equal file qualities where resolution and/or quality move in the opposite direction of source' do
      expect(described_class.new(common_info)).to be_equivalent_to described_class.new(
        common_info.merge(source: 'VHS', video_resolution: '1920x1080'),
      )
      expect(described_class.new(common_info)).to be_equivalent_to described_class.new(
        common_info.merge(source: 'Blu-ray', quality: 'low'),
      )
      expect(described_class.new(common_info)).to be_equivalent_to described_class.new(
        common_info.merge(source: 'Blu-ray', quality: 'low', video_resolution: '1920x1080'),
      )
    end

    it 'ignores version' do
      expect(described_class.new(common_info)).to be > described_class.new(
        common_info.merge(source: 'VHS', version: 3),
      )
      expect(described_class.new(common_info)).to be < described_class.new(
        common_info.merge(source: 'Blu-ray', version: 1),
      )
    end
  end
end
