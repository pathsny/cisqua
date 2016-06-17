require 'faye/websocket'
require 'concurrent-edge'
require_relative '../../lib/loggers.rb'

class LogTailer
  KEEPALIVE_TIME = 15 # in seconds
  @clients = Concurrent::Map.new
  @tailing = Concurrent::AtomicBoolean.new

  class << self
    def add_client(ws)
      @clients[ws.object_id] = ws
      start_tailing_maybe
    end
    
    def remove_client(ws)
      @clients.delete(ws.object_id)
      stop_tailing_maybe
    end  

    def start_tailing_maybe
      changed = @tailing.make_true
      return unless changed
      Loggers::LogTailer.debug { "starting to tail logs " }
      Thread.new do
        r, @w = IO.pipe
        f = IO.popen("tail -n0 -F #{Logging.parseable_logfile}")
        loop do
          select([f, r])
          break if @tailing.false?
          while line = f.gets
            break if @tailing.false?
            @clients.each_value { |ws| ws.send(line)}
          end
        end    
        Loggers::LogTailer.debug { "stopped tailing logs" }
      end  
    end

    def stop_tailing_maybe
      return unless @clients.empty?
      changed = @tailing.make_false
      if changed
        @w.write ""
        @w.close
        Loggers::LogTailer.debug { "requested stop tailing" }
      end  
    end
  end  

  def initialize(app)
    @app = app
  end

  def call(env)
    if Faye::WebSocket.websocket?(env)
      ws = Faye::WebSocket.new(env, nil, {ping: KEEPALIVE_TIME })
      ws.on :open do |event|
        Loggers::LogTailer.debug {
          "new client connected #{ws.object_id}"
        }
        loglines = `tail -n 100 #{Logging.parseable_logfile}`
        ws.send(loglines.split("\n").to_json)
        self.class.add_client(ws)
      end

      ws.on :message do |event|
        Loggers::LogTailer.debug {
          "unexpected message from #{ws.object_id}: #{event.data}"
        }
      end

      ws.on :close do |event|
        Loggers::LogTailer.debug {
          "connection closed by #{ws.object_id} with code #{event.code} reason #{event.reason}"
        }
        self.class.remove_client(ws)
        ws = nil
      end
      ws.rack_response
    else
      @app.call(env)
    end
  end
end

