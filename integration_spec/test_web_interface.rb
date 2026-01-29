require 'faraday'
require 'open3'
require 'net/http'
require 'json'
require 'ld-eventsource'
require 'timeout'

class TestWebInterface
  include SemanticLogger::Loggable
  def start
    logger.info('starting web interface')
    @stdin, @stdout, @stderr, @wait_thr = Open3.popen3(
      'RACK_ENV=test bundle exec ruby app.rb --stub-transmission torrents.json',
    )

    begin
      Timeout.timeout(10) do
        sleep(0.5) until server_ready?
      end
    rescue Timeout::Error
      raise 'Server did not start within 10 seconds'
    end

    conn = Faraday.new('http://localhost:4567') do |faraday|
      faraday.request :json
    end
    response = conn.post('/test/transmission_stub', {
      stub_file: 'torrents.json',
    })
    assert(response.status == 200, "must get back success but got back #{response.status} #{response.body}")
  end

  def server_ready?
    response = Faraday.get('http://localhost:4567/health_check') # Adjust the endpoint as necessary
    response.status == 200
  rescue Faraday::ConnectionFailed
    false
  end

  def stop
    Process.kill('TERM', @wait_thr.pid)

    # Ensure all resources are closed
    @stdin.close
    @stdout.close
    @stderr.close
  end

  def run
    response = Faraday.post('http://localhost:4567/start_scan', {
      queried_timestamp: Time.now.to_i,
    })
    assert(
      response.status == 200,
      "must get back success but got back #{response.status} #{response.body}",
    )
    data = JSON.parse(response.body)
    assert(data['scan_enque_result'], 'started')
    new_timestamp = data['updates']['last_update']['checked_timestamp']

    uri = URI::HTTP.build(
      host: 'localhost',
      port: 4567,
      path: '/refresh',
      query: "queried_timestamp=#{new_timestamp}",
    )
    queue = Queue.new

    sse_client = SSE::Client.new(uri) do |client|
      client.on_event do |event|
        data = JSON.parse(event.data)
        batch_check_data = data.dig('last_update', 'scans')
        if batch_check_data && !batch_check_data['scan_in_progress']
          sse_client.close
          queue << true
        end
      end
    end
    queue.pop
  end

  def hack_udp_cache_for_test(cache_swap)
    response = Faraday.post('http://localhost:4567/test/hack_udp_cache', cache_swap.to_json,
      'Content-Type' => 'application/json')
    assert(response.status == 200, "Failed to swap UDP cache: #{response.body}")
  end

  def anime_data(aid)
    fetch_data("/anime/#{aid}")
  end

  def scan_count
    fetch_data('/scans/count')
  end

  def scan_data(scan_id)
    fetch_data("/scans/#{scan_id}")
  end

  def fetch_data(url_path)
    response = Faraday.get("http://localhost:4567/#{url_path}")
    assert(response.status == 200, 'must get back success')
    JSON.parse(response.body)
  end
end
