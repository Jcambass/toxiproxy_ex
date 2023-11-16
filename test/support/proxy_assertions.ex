defmodule ToxiproxyEx.ProxyAssertions do
  import ExUnit.Assertions

  alias ToxiproxyEx.Proxy
  alias ToxiproxyEx.TestHelpers

  def assert_proxy_available(%Proxy{} = proxy) do
    case TestHelpers.connect_to_proxy(proxy) do
      {:ok, socket} ->
        :gen_tcp.close(socket)

      {:error, reason} ->
        flunk("""
        Proxy #{proxy.name} (shown below) should be available, but is not: \
        #{:inet.format_error(reason)}

          #{inspect(proxy)}
        """)
    end
  end

  def assert_proxy_unavailable(%Proxy{} = proxy) do
    case TestHelpers.connect_to_proxy(proxy) do
      {:error, :econnrefused} ->
        :ok

      {:ok, socket} ->
        :gen_tcp.close(socket)
        flunk("Proxy #{proxy.name} is available but should not be")
    end
  end
end
