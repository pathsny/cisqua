# represents the quality of a specific file. This can be used to compare
# files. However, it is only meaningful to compare files of the same show,
# episode and group.
module Cisqua
  module Renamer
    module Comparable
      include ::Comparable

      def consistent_comparison(*comparisons)
        differing = comparisons.select { |h| h[:comp] != 0 }
        comps = differing.map { |h| h[:comp] }
        attrs = differing.map { |h| h[:attr] }
        # return 0 if you have atleast two comparisons that are of opposite signs (i.e -1 and 1)
        return { comp: 0, attrs: } if comps.empty? || (comps & [-1, 1]).sort == [-1, 1]

        { comp: comps.reduce(:|), attrs: }
      end
    end

    class Source
      extend Cisqua::Reloadable
      include Comparable

      attr_reader :name

      @all_instances = []

      def to_s
        name
      end

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
      reloadable_const_define :TV, make_instance('TV', 4)
      reloadable_const_define :DTV, make_instance('DTV', 4)
      reloadable_const_define :LD, make_instance('LD', 4)
      reloadable_const_define :HKDVD, make_instance('HKDVD', 4)
      reloadable_const_define :WWW, make_instance('www', 4)
      reloadable_const_define :HDTV, make_instance('HDTV', 6)
      reloadable_const_define :DVD, make_instance('DVD', 6)
      reloadable_const_define :HD_DVD, make_instance('HD-DVD', 8)
      reloadable_const_define :BLU_RAY, make_instance('Blu-ray', 8)

      protected

      attr_reader :score
    end

    class Quality
      extend Cisqua::Reloadable
      include Comparable

      attr_reader :name

      @all_instances = []

      def to_s
        name
      end

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
      reloadable_const_define :VERY_LOW, make_instance('very low', 2)
      reloadable_const_define :LOW, make_instance('low', 4)
      reloadable_const_define :MED, make_instance('med', 6)
      reloadable_const_define :HIGH, make_instance('high', 7)
      reloadable_const_define :VERY_HIGH, make_instance('very high', 8)

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
        @res_string = res_string
        @width = m[1].to_i
        @height = m[2].to_i
      end

      def to_s
        @res_string
      end

      def <=>(other)
        consistent_comparison(
          { attr: :width, comp: width <=> other.width },
          { attr: :height, comp: height <=> other.height },
        )[:comp]
      end
    end

    class FileQuality
      extend Cisqua::Reloadable
      include Comparable

      def initialize(options)
        @version = options[:version]
        @quality = Quality.new(options[:quality])
        @source = Source.new(options[:source])
        @video_resolution = VideoResolution.new(options[:video_resolution])
        assert(
          @version.is_a?(Integer) && @version >= 1 && @version <= 5,
          'quality requires a valid version',
        )
      end

      attr_reader :version, :quality, :source, :video_resolution

      def <=>(other)
        compare_with_info(other)[:comp]
      end

      def attr_hash(attrs)
        attrs.each_with_object({}) do |attr, hsh|
          hsh[attr] = send(attr).to_s
        end
      end

      def compare_with_info(other)
        source_cmp = source <=> other.source
        result = if source_cmp.zero?
          consistent_comparison(
            { attr: :quality, comp: quality <=> other.quality },
            { attr: :version, comp: version <=> other.version },
            { attr: :video_resolution, comp: video_resolution <=> other.video_resolution },
          )
        else
          consistent_comparison(
            { attr: :source, comp: source_cmp },
            { attr: :quality, comp: quality <=> other.quality },
            { attr: :video_resolution, comp: video_resolution <=> other.video_resolution },
          )
        end
        {
          comp: result[:comp],
          left: attr_hash(result[:attrs]),
          right: other.attr_hash(result[:attrs]),
        }
      end
    end
  end
end
