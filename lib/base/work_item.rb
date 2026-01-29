module Cisqua
  reloadable_const_define :WorkItem do
    Struct.new(
      # can be :standard for regular processing. Or :duplicate_set to indicate that
      # we're reprocessing a processed file and comparing it against one or more
      # duplicates that could replace this file.
      :request_type,
      # work_item_source
      :source,
      # A unique index (scoped to a batch). Can be used by observers to track updates
      :index,
      # AnimeFile object
      :file,
      # The result after the file was identified and processed
      :result,
      # WorkItems currently being processed that were identified to be a duplicate
      # of this file that has already been stored.
      :duplicate_work_items,
      # An object encapsulating the quality of the item
      :quality,
      keyword_init: true,
    ) do
      def quality
        @quality ||= make_quality
      end

      private

      def make_quality
        assert(fid, 'file quality can only be retrieved after info is obtained')
        Renamer::FileQuality.new(fid)
      end
    end
  end
end
