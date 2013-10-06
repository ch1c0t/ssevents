require 'reel'

class Ssevents < Reel::Server
  include Celluloid::Logger

  def initialize data_source, ip = '127.0.0.1', port = 44444
    @connections = []
    @data_source = data_source
    @data = ''

    async.ring

    super ip, port, &method(:on_connection)
  end

  private

  def broadcast data
    @data = data

    info "Sending data to #{@connections.count} client(s)."
    @connections.each do |socket|
      async.send_sse socket, data
    end
  end

  def send_sse socket, data
    begin
      socket.data data
    rescue IOError, Errno::ECONNRESET, Errno::EPIPE
      @connections.delete socket
    end
  end

  def on_connection connection
    connection.each_request do |request|
      handle_request request
    end
  end

  def handle_request request
    body = Reel::EventStream.new do |socket|
      @connections << socket
      socket << "data: #{@data}\n\n"
    end

    headers = {
      'Content-Type'                => 'text/event-stream; charset=utf-8',
      'Cache-Control'               => 'no-cache',
      'Access-Control-Allow-Origin' => '*'
    }

    request.respond Reel::StreamResponse.new(:ok, headers, body)
  end

  def ring
    every 1 do
      broadcast @data_source.call
    end
  end
end
