# represents the quality of a specific file. This can be used to compare
# files. However, it is only meaningful to compare files of the same show,
# episode and group.
module Cisqua
  module Renamer
    module Comparable
      include ::Comparable

      def consistent_comparison(*comps)
        # return 0 if you have atleast two comparisons that are of opposite signs (i.e -1 and 1)
        return 0 if (comps & [-1, 1]).sort == [-1, 1]

        comps.reduce(:|)
      end
    end

    class Source
      extend Cisqua::Reloadable
      include Comparable

      attr_reader :name

      @all_instances = []

      class << self
        def new(name)
          @all_instances.find { |i| i.name == name }.tap do |inst|
            assert(!inst.nil?, "#{name} is not a valid source")
          end
        end

        private

        def make_instance(name, score)
          allocate.tap do |inst|
            inst.instance_variable_set(:@name, name)
            inst.instance_variable_set(:@score, score)
            @all_instances.push(inst)
          end
        end
      end

      def <=>(other)
        return 0 if self == UNKNOWN || other == UNKNOWN

        score <=> other.score
      end

      reloadable_const_define :UNKNOWN, make_instance('unknown', nil)
      reloadable_const_define :CAMCORDER, make_instance('camcorder', 1)
      reloadable_const_define :VHS, make_instance('VHS', 2)
      reloadable_const_define :VCD, make_instance('VCD', 2)
      reloadable_const_define :SVCD, make_instance('SVCD', 2)
      reloadable_const_define :TV, make_instance('TV', 3)
      reloadable_const_define :DTV, make_instance('DTV', 3)
      reloadable_const_define :LD, make_instance('LD', 3)
      reloadable_const_define :HKDVD, make_instance('HKDVD', 3)
      reloadable_const_define :WWW, make_instance('www', 3)
      reloadable_const_define :HDTV, make_instance('HDTV', 4)
      reloadable_const_define :DVD, make_instance('DVD', 4)
      reloadable_const_define :HD_DVD, make_instance('HD-DVD', 5)
      reloadable_const_define :BLU_RAY, make_instance('Blu-ray', 5)

      protected

      attr_reader :score
    end

    class Quality
      extend Cisqua::Reloadable
      include Comparable

      attr_reader :name

      @all_instances = []

      class << self
        def new(name)
          @all_instances.find { |i| i.name == name }.tap do |inst|
            assert(!inst.nil?, "#{name} is not a valid source")
          end
        end

        private

        def make_instance(name, score)
          allocate.tap do |inst|
            inst.instance_variable_set(:@name, name)
            inst.instance_variable_set(:@score, score)
            @all_instances.push(inst)
          end
        end
      end

      def <=>(other)
        score <=> other.score
      end

      reloadable_const_define :EYECANCER, make_instance('eyecancer', 1)
      reloadable_const_define :LOW, make_instance('very low', 2)
      reloadable_const_define :LOW, make_instance('low', 3)
      reloadable_const_define :MED, make_instance('med', 4)
      reloadable_const_define :HIGH, make_instance('high', 5)
      reloadable_const_define :VERY_HIGH, make_instance('very high', 6)

      protected

      attr_reader :score
    end

    class VideoResolution
      extend Cisqua::Reloadable
      include Comparable

      reloadable_const_define :PATTERN, /^(\d+)x(\d+)$/

      attr_reader :width, :height

      def initialize(res_string)
        m = PATTERN.match(res_string)
        assert(m, 'video resolution is not parseable')
        @width = m[1].to_i
        @height = m[2].to_i
      end

      def <=>(other)
        consistent_comparison(width <=> other.width, height <=> other.height)
      end
    end

    class FileQuality
      extend Cisqua::Reloadable
      include Comparable

      def initialize(options)
        @version = options[:version]
        @quality = Quality.new(options[:quality])
        @source = Source.new(options[:source])
        @res = VideoResolution.new(options[:video_resolution])
        assert(
          @version.is_a?(Integer) && @version >= 1 && @version <= 5,
          'quality requires a valid version',
        )
      end

      attr_reader :version, :quality, :source, :res

      def <=>(other)
        source_cmp = source <=> other.source
        if source_cmp.zero?
          consistent_comparison(
            quality <=> other.quality,
            version <=> other.version,
            res <=> other.res,
          )
        else
          consistent_comparison(
            source_cmp,
            quality <=> other.quality,
            res <=> other.res,
          )
        end
      end
    end
  end
end
