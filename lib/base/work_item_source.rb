module Cisqua
  reloadable_const_define :WorkItemSource do
    Struct.new(
      :name,
      :path,
      :ed2k,
      :size_bytes,
      keyword_init: true,
    )
  end
end
