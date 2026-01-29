class TransmissionStub
  include SemanticLogger::Loggable
  include Singleton

  def initialize
    @mode = :stub
  end

  attr_reader :stub_file, :previous_adapter
  attr_accessor :mode

  def register_middleware
    Faraday::Adapter.lookup_middleware(:transmission_stub)
  rescue StandardError => _e
    Faraday::Adapter.register_middleware transmission_stub: TransmissionStubAdapter

    return if Faraday.default_adapter == :transmission_stub

    @previous_adapter = Faraday.default_adapter
    Faraday.default_adapter = :transmission_stub
    logger.info("Set adapter to #{Faraday.default_adapter}")
  end

  def restore_adapter
    Faraday.default_adapter = @previous_adapter
    logger.info("Restored adapter to #{@previous_adapter}")
  end

  def use_file(file_path)
    @stub_file = file_path
    logger.info("transmission stub mode using file: #{file_path}")
  end

  def stub_data
    assert(@stub_file, 'Stub file not set')
    assert(File.exist?(@stub_file), "Stub file #{@stub_file} does not exist")

    File.read(@stub_file)
  rescue JSON::ParserError => e
    logger.error("Failed to parse stub file: #{e.message}")
    {}
  end

  def save_stub_data(data)
    assert(@stub_file, 'Stub file not set')
    File.write(@stub_file, JSON.pretty_generate(JSON.parse(data)))
  end
end

class TransmissionStubAdapter < Faraday::Adapter
  include SemanticLogger::Loggable

  def initialize(app, options = {}, &)
    super
    @default_adapter = Faraday::Adapter::NetHttp.new(app, options, &)
  end

  def call(env)
    super

    if TransmissionStub.instance.mode == :capture
      # Let the request go through and capture the response
      logger.info("Capturing response for #{@default_adapter.class}")
      response = @default_adapter.call(env)
      logger.info("Captured response for #{env.url.path}")
      capture_response(env, response)
      return @app.call(env)
    end

    assert(TransmissionStub.instance.mode == :stub, "Invalid mode: #{TransmissionStub.instance.mode}")
    stub_body = TransmissionStub.instance.stub_data
    response = {
      status: 200,
      body: stub_body,
      headers: {
        'server' => 'Transmission',
        'access-control-allow-origin' => '*',
        'content-type' => 'application/json; charset=UTF-8',
        'date' => 'Fri, 07 Mar 2025 18:34:08 GMT',
        'content-length' => (stub_body.length + 2).to_s,
        'connection' => 'close',
      },
      reason_phrase: 'OK',
    }
    save_response(env, *%i[status body headers reason_phrase].map { |k| response[k] }) do |response_headers|
      response[:headers].each do |key, value|
        response_headers[key] = value
      end
    end
    @app.call(env)
  rescue StandardError => e
    logger.error('Error in TransmissionStubAdapter:', e)
    raise e
  end

  private

  def capture_response(env, response)
    return if response.status == 409

    logger.info("Capturing response for #{env.url.path}")
    assert(response.status == 200, "must get back success but got back #{response.status} #{response.body}")
    assert(
      Faraday::Utils.normalize_path(env[:url].path) == '/transmission/rpc',
      "unexpected path #{Faraday::Utils.normalize_path(env[:url].path)}",
    )
    TransmissionStub.instance.save_stub_data(response.body)

    # stub_data = TransmissionStub.instance.stub_data
    # key = request_key(env)

    # stub_data[key] = {
    #   'path' => Faraday::Utils.normalize_path(env[:url].path),
    #   'method' => env[:method],
    #   'params' => env[:params],
    #   'response' => {
    #     'status' => response.status,
    #     'headers' => response.headers,
    #     'body' => response.body.to_s,
    #     'reason_phrase' => response.reason_phrase,
    #   },
    # }
    # logger.info("Saving stub data for #{key} ")
  end

  def find_matching_stub(env)
    stub_data = TransmissionStub.instance.stub_data
    key = request_key(env)
    stub_data[key]
  end

  def request_key(env)
    {
      host: env[:url].host,
      path: Faraday::Utils.normalize_path(env[:url].path),
    }.sort.to_h.to_json
  end
end
