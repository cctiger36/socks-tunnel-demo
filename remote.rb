require "eventmachine"
require_relative "config"
require_relative "coder"

class RemoteConnection < EventMachine::Connection
  attr_accessor :server

  def receive_data(data)
    @server.send_encoded_data(data)
  end

  def unbind
    @server.close_connection_after_writing
  end
end

class RemoteServer < EventMachine::Connection
  def post_init
    @coder = Coder.new
    @buffer = ""
  end

  def send_encoded_data(data)
    return if data.nil? || data.empty?
    send_data(@coder.encode(data))
    send_data(Config[:delimiter])
  end

  def receive_data(data)
    if @connection
      @buffer << data
      loop do
        fore, rest = @buffer.split(Config[:delimiter], 2)
        break unless rest
        @connection.send_data(@coder.decode(fore))
        @buffer = rest
      end
    else
      @buffer << data
      addr, rest = @buffer.split(Config[:delimiter], 2)
      if rest
        addr = @coder.decode(addr)
        host, port = addr.split(":")
        port = (port.nil? || port.empty?) ? 80 : port.to_i
        @buffer = rest
        @connection = EventMachine.connect(host, port, RemoteConnection)
        @connection.server = self
        loop do
          fore, rest = @buffer.split(Config[:delimiter], 2)
          break unless rest
          @connection.send_data(@coder.decode(fore))
          @buffer = rest
        end
      end
    end
  rescue
    @connection.close_connection if @connection
    close_connection
  end

  def unbind
    @connection.close_connection if @connection
  end
end

EventMachine.run do
  puts "Start server at 0.0.0.0:#{Config[:remote_server_port]}"
  EventMachine.start_server('0.0.0.0', Config[:remote_server_port], RemoteServer)
end
