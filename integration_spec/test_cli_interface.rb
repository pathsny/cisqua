class TestCLIInterface
  def start
    TransmissionStub.instance.use_file('torrents.json')
    TransmissionStub.instance.register_middleware

    @processor = Cisqua::PostProcessor.new(
      Cisqua::Registry.instance.options,
      Cisqua::Registry.instance.scanner,
      Cisqua::FileProcessor.instance,
    )
    @processor.start
  end

  def stop
    @processor.stop
  end

  def run
    @processor.run
  end

  def hack_udp_cache_for_test(cache_swap)
    Cisqua::TestUtil.hack_udp_cache(cache_swap)
  end

  def anime_data(aid)
    make_comparable(Cisqua::Registry.instance.view_data.for_anime_id(aid))
  end

  def scan_count
    Cisqua::BatchCheck.instance.latest(:all).count
  end

  def scan_data(scan_id)
    make_comparable(Cisqua::Registry.instance.view_data.for_batch_data(Cisqua::BatchData.find(scan_id)))
  end

  # serializes to json and parses back. This is to deal with strings vs symbols
  def make_comparable(data)
    JSON.parse(data.to_json)
  end
end
