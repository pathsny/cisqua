WorkItem = Struct.new("WorkItem", :file, :info) do
  def quality
    @quality ||= make_quality
  end

  private
  def make_quality
    assert(info, "file quality can only be retrieved after info is obtained")
    FileQuality.new(info[:file])
  end
end
