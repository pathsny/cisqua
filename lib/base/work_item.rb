module Cisqua
  reloadable_const_define :WorkItem do
    Struct.new(
      :file,
      :info,
      :renamer_status,
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
