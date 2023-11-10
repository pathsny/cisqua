module Cisqua
  reloadable_const_define :WorkItem do
    Struct.new(
      # can be :standard for regular processing. Or :duplicate_set to indicate that
      # we're reprocessing a processed file and comparing it against one or more
      # duplicates that could replace this file.
      :request_type,
      :file,
      :info,
      :result,
      :duplicate_work_items,
      keyword_init: true,
    ) do
      def quality
        @quality ||= make_quality
      end

      private

      def make_quality
        assert(info, 'file quality can only be retrieved after info is obtained')
        Renamer::FileQuality.new(info[:file])
      end
    end
  end
end
