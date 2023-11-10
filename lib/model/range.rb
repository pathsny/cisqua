require 'active_model'
require_relative 'redisable'

module Cisqua
  class Range
    include Model::IDKeyable
    include SemanticLogger::Loggable

    key_prefix :'mylist:range'

    string_attrs :simple, :with_groups

    def self.make_for_anime(aid)
      files = MyList.files(aid)
      range_strings = MakeRange.new.parts_with_groups_strings(aid, files)
      new(
        id: aid,
        **range_strings,
        updated_at: Time.now,
      ).save
    end
  end
end
