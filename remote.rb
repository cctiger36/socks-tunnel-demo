require "eventmachine"
require_relative "coder"

REMOTE_SERVER_PORT = "8082"
DELIMITER = "DRECOMADVENTCALENDER"

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
    send_data(DELIMITER)
  end

  def receive_data(data)
    if @connection
      @buffer << data
      loop do
        fore, rest = @buffer.split(DELIMITER, 2)
        break unless rest
        @connection.send_data(@coder.decode(fore))
        @buffer = rest
      end
    else
      @buffer << data
      addr, rest = @buffer.split(DELIMITER, 2)
      if rest
        addr = @coder.decode(addr)
        host, port = addr.split(":")
        port = (port.nil? || port.empty?) ? 80 : port.to_i
        @buffer = rest
        @connection = EventMachine.connect(host, port, RemoteConnection)
        @connection.server = self
        loop do
          fore, rest = @buffer.split(DELIMITER, 2)
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
  puts "Starting server at 0.0.0.0:#{REMOTE_SERVER_PORT}"
  EventMachine.start_server('0.0.0.0', REMOTE_SERVER_PORT, RemoteServer)
end
