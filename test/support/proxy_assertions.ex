defmodule ToxiproxyEx.ProxyAssertions do
  defmacro assert_proxy_available(proxy) do
    quote do
      case connect_to_proxy(unquote(proxy)) do
        {:ok, _socket} -> assert true
        _ -> flunk("Proxy #{unquote(proxy).name} is not available but should be")
      end
    end
  end

  defmacro assert_proxy_unavailable(proxy) do
    quote do
      case connect_to_proxy(unquote(proxy)) do
        {:error, :econnrefused} -> assert true
        _ -> flunk("Proxy #{unquote(proxy).name} is available but should not be")
      end
    end
  end
end
