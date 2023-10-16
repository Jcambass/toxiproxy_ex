defmodule ToxiproxyEx.TestHelpers do
  import ExUnit.Assertions

  alias ToxiproxyEx.EchoServer

  def connect_to_proxy(proxy) do
    assert [hostname, port] = String.split(proxy.listen, ":")

    hostname = String.to_charlist(hostname)
    assert {port, ""} = Integer.parse(port)

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

  def with_tcpservers(count, fun) when is_integer(count) do
    parent_pid = self()
    ref = make_ref()

    tasks =
      Enum.map(1..count, fn _i ->
        task =
          Task.async(fn ->
            {socket, port} = EchoServer.create()
            send(parent_pid, {:port, ref, port})
            EchoServer.start(socket)
          end)

        assert_receive {:port, ^ref, port}, 100

        {task, port}
      end)

    ports = Enum.map(tasks, fn {_task, port} -> port end)

    try do
      fun.(ports)
    after
      Enum.each(tasks, fn {task, _port} -> Task.shutdown(task) end)
    end
  end

  def with_tcpserver(fun) do
    with_tcpservers(1, fn [port] -> fun.(port) end)
  end
end
