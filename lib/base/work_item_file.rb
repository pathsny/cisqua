module Cisqua
  reloadable_const_define :WorkItemFile do
    Struct.new(
      :name,
      :path,
      :ed2k,
      :size_bytes,
      keyword_init: true,
    )
  end
end
