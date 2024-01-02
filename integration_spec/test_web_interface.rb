require 'faraday'
require 'open3'
require 'net/http'
require 'json'
require 'ld-eventsource'

class TestWebInterface < TestInterface
  def prep; end

  def start
    Cisqua::TestUtil.prep_for_integration_test(log_level: :debug)
    @stdin, @stdout, @stderr, @wait_thr = Open3.popen3('bundle exec ruby app.rb -t')

    # Optionally, give the server a few seconds to start up.
    sleep(2)
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
      'queried-timestamp' => Time.now.to_i,
    })
    assert(response.status == 200, 'must get back success')
    data = JSON.parse(response.body)
    assert(data['scan_enque_result'], 'started')
    new_timestamp = data['updates']['queried_timestamp']

    uri = URI::HTTP.build(
      host: 'localhost',
      port: 4567,
      path: '/refresh',
      query: "queried-timestamp=#{new_timestamp}",
    )
    queue = Queue.new

    sse_client = SSE::Client.new(uri) do |client|
      client.on_event do |event|
        data = JSON.parse(event.data)
        unless data['latest_check']['scan_in_progress']
          sse_client.close
          queue << true
        end
      end
    end
    queue.pop
  end
end
