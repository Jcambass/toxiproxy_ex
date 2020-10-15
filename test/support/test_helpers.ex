defmodule ToxiproxyEx.TestHelpers do
  alias ToxiproxyEx.EchoServer

  def connect_to_proxy(proxy) do
    [hostname, port] = String.split(proxy.listen, ":")

    hostname = String.to_charlist(hostname)
    {port, _rem} = Integer.parse(port)

    :gen_tcp.connect(hostname, port, [
      :binary,
      packet: :line,
      active: false
    ])
  end

  def write_to_proxy(proxy, message) do
    {:ok, socket} = connect_to_proxy(proxy)
    :ok = :gen_tcp.send(socket, "#{message}\n")
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end

  def measure(fun) do
    {duration, res} = :timer.tc(fun)
    {duration / 1_000, res}
  end

  def with_tcpservers(count, fun) do
    servers =
      Enum.map(1..count, fn _i ->
        EchoServer.create()
      end)

    server_pids =
      Enum.map(servers, fn {socket, _port} ->
        spawn(fn ->
          EchoServer.start(socket)
        end)
      end)

    ports = Enum.map(servers, fn {_socket, port} -> port end)

    fun.(ports)

    Enum.each(server_pids, fn pid ->
      Process.exit(pid, :kill)
    end)

    Enum.each(servers, fn {socket, _port} ->
      EchoServer.stop(socket)
    end)
  end

  def with_tcpserver(fun) do
    with_tcpservers(1, fn ports ->
      fun.(hd(ports))
    end)
  end
end
