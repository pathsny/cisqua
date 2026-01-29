describe Cisqua::Renamer::NameGenerator do
  RSpec::Matchers.define :be_moved_to do |expected_path|
    chain :and_named_as, :expected_name

    match do |file|
      actual_path = subject.generate_dir_name_for_file(file)
      condition = actual_path == expected_path
      unless expected_name.nil?
        actual_name = subject.generate_name(file)
        condition &&= actual_name == expected_name
      end
      condition
    end

    failure_message do |file|
      actual_path = subject.generate_dir_name_for_file(file)
      actual_name = subject.generate_name(file)
      error = "expected that #{file.raw_file_name} would"
      if actual_path != expected_path
        error +=
          " be moved to #{expected_path}, " \
          "but it was moved to #{actual_path},"
      end
      if !expected_name.nil? && actual_name != expected_name
        error +=
          " be named as #{expected_name}, " \
          "but it was named as #{actual_name},"
      end
      error
    end
  end

  def file(raw_file_name)
    subject.stubs(:generate_name_impl).returns("#{raw_file_name}.mkv")
    stub(anime: stub(romaji_name: raw_file_name), raw_file_name:)
  end

  subject { described_class }

  it {
    expect(file('fate/stay')).to be_moved_to('fate stay').and_named_as('fate stay.mkv')
  }

  it {
    expect(file('macross: the movie')).to be_moved_to('macross the movie')
      .and_named_as('macross the movie.mkv')
  }

  it {
    expect(file('space :movie')).to be_moved_to('space movie')
      .and_named_as('space movie.mkv')
  }

  it {
    expect(file('//hack root')).to be_moved_to('hack root')
      .and_named_as('hack root.mkv')
  }

  it {
    expect(file('hi there $$ man')).to be_moved_to('hi there man')
      .and_named_as('hi there man.mkv')
  }

  it {
    expect(file('hello%%%romeo')).to be_moved_to('hello romeo')
      .and_named_as('hello romeo.mkv')
  }

  it {
    expect(file('blaaah   blueeee    bleeeeeeh')).to be_moved_to('blaaah blueeee bleeeeeeh')
      .and_named_as('blaaah blueeee bleeeeeeh.mkv')
  }
end
