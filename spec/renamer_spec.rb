require File.expand_path('../spec_helper', __FILE__)

describe Renamer do
  describe Renamer::NameGenerator do
    RSpec::Matchers.define :rename_to do |expected|
      match do |actual|
        subject.generate_name_and_path(actual) == expected 
      end
      
      failure_message do |actual|
          "expected that #{actual} would be renamed to to #{expected}," +
          " but it was renamed to #{subject.generate_name_and_path(actual)}"
      end
    end

    def make_path_and_name(s)
      [s, s + ".mkv"]
    end  

    subject { Renamer::NameGenerator.new(method(:make_path_and_name))}

    it { expect('fate/stay').to rename_to ['fate stay', 'fate stay.mkv'] }
    it { expect('macross: the movie').to rename_to ['macross the movie', 'macross the movie.mkv'] }
    it { expect('space :movie').to rename_to ['space movie', 'space movie.mkv'] }
    it { expect('//hack root').to rename_to ['hack root', 'hack root.mkv']}
    it { expect('hi there $$ man').to rename_to ['hi there man', 'hi there man.mkv'] }
    it { expect('hello%%%romeo').to rename_to ["hello romeo", "hello romeo.mkv"] }
    it { expect('blaaah   blueeee    bleeeeeeh').to rename_to ['blaaah blueeee bleeeeeeh', 'blaaah blueeee bleeeeeeh.mkv']}
  end
end