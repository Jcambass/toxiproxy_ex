defmodule ToxiproxyEx.EchoServer do
  def create do
    {:ok, socket} =
      :gen_tcp.listen(
        0,
        [:binary, packet: :line, active: false, reuseaddr: true]
      )

    {:ok, port} = :inet.port(socket)

    {socket, port}
  end

  def start(socket) do
    loop_acceptor(socket)
  end

  def stop(socket) do
    :gen_tcp.close(socket)
  end

  defp loop_acceptor(socket) do
    case :gen_tcp.accept(socket) do
      {:ok, client} ->
        Task.start_link(fn -> serve(client) end)
        loop_acceptor(socket)

      {:error, :closed} ->
        nil
    end
  end

  defp serve(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        :gen_tcp.send(socket, data)
        serve(socket)

      {:error, :closed} ->
        nil
    end
  end
end
