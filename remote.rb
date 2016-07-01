require "eventmachine"
require "socket"
require_relative "buffer"
require_relative "coder"
require_relative "config"

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
    @buffer = Buffer.new
  end

  def send_encoded_data(data)
    return if data.nil? || data.empty?
    send_data(@coder.encode(data))
    send_data(Config[:delimiter])
  end

  def receive_data(data)
    if @connection
      @buffer << data
      @buffer.each do |segment|
        @connection.send_data(@coder.decode(segment))
      end
    else
      validate_client_ip
      @buffer << data
      addr = @buffer.shift
      if addr
        addr = @coder.decode(addr)
        host, port = addr.split(":")
        port = (port.nil? || port.empty?) ? 80 : port.to_i
        @connection = EventMachine.connect(host, port, RemoteConnection)
        @connection.server = self
        @buffer.each do |segment|
          @connection.send_data(@coder.decode(segment))
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

  def validate_client_ip
    port, ip = Socket.unpack_sockaddr_in(get_peername)
    raise "Invalid client" unless ip == Config[:local_server_host]
  end
end

EventMachine.run do
  puts "Start server at 0.0.0.0:#{Config[:remote_server_port]}"
  EventMachine.start_server('0.0.0.0', Config[:remote_server_port], RemoteServer)
end
