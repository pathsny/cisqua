# represents the quality of a specific file. This can be used to compare
# files. However, it is only meaningful to compare files of the same show,
# episode and group.
class Source
  include Comparable
  attr_reader :name
  @all_instances = []

  class << self
    def new(name)
      @all_instances.find {|i| i.name == name}.tap do |inst|
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
    return score <=> other.score
  end

  UNKNOWN = make_instance("unknown", nil)
  CAMCORDER = make_instance("camcorder", 1)
  VHS = make_instance("VHS", 2)
  VCD = make_instance("VCD", 2)
  SVCD = make_instance("SVCD", 2)
  TV = make_instance("TV", 3)
  DTV = make_instance("DTV", 3)
  LD = make_instance("LD", 3)
  HKDVD = make_instance("HKDVD", 3)
  WWW = make_instance("www", 3)
  HDTV = make_instance("HDTV", 4)
  DVD = make_instance("DVD", 4)
  HD_DVD = make_instance("HD-DVD", 5)
  BLU_RAY = make_instance("Blu-ray", 5)

  protected
  attr_reader :score
end

class Quality
  include Comparable
  attr_reader :name
  @all_instances = []

  class << self
    def new(name)
      @all_instances.find {|i| i.name == name}.tap do |inst|
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
    return score <=> other.score
  end

  EYECANCER = make_instance("eyecancer", 1)
  VERY_LOW = make_instance("very low", 2)
  LOW = make_instance("low", 3)
  MED = make_instance("med", 4)
  HIGH = make_instance("high", 5)
  VERY_HIGH = make_instance("very high", 6)

  protected
  attr_reader :score
end

class VideoResolution
  include Comparable
  PATTERN = /^(\d+)x(\d+)$/

  attr_reader :width, :height

  def initialize(res_string)
    m = PATTERN.match(res_string)
    assert(m, "video resolution is not parseable")
    @width, @height = m[1].to_i, m[2].to_i
  end

  def <=>(other)
    consistent_comparison(width <=> other.width, height <=> other.height)
  end
end


class FileQuality
  include Comparable
  def initialize(options)
    @version = options[:version]
    @quality = Quality.new(options[:quality])
    @source = Source.new(options[:source])
    @res = VideoResolution.new(options[:video_resolution])
    assert(
      @version.is_a?(Integer) && 1 <= @version && @version <= 5,
      'quality requires a valid version'
    )
  end

  attr_reader :version, :quality, :source, :res

  def <=>(other)
    source_cmp = source <=> other.source
    return source_cmp == 0 ?
      consistent_comparison(
        quality <=> other.quality,
        version <=> other.version,
        res <=> other.res
      ) :
      consistent_comparison(
        source_cmp,
        quality <=> other.quality,
        res <=> other.res
      )
  end
end

def consistent_comparison(*comps)
  # return 0 if you have atleast two comparisons that are of opposite signs (i.e -1 and 1)
  return 0 if (comps & [-1, 1]).sort == [-1, 1]
  comps.reduce(:|)
end
