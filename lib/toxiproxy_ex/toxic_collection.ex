defmodule ToxiproxyEx.ToxicCollection do
  @moduledoc false

  alias ToxiproxyEx.{Proxy, Toxic}

  @typedoc since: "1.2.0"
  @type t() :: %__MODULE__{
          proxies: [Proxy.t()],
          toxics: [Toxic.t()]
        }

  defstruct proxies: [], toxics: []

  @spec new([Proxy.t()] | Proxy.t()) :: t()
  def new(proxies_or_proxy)

  def new(proxies) when is_list(proxies) do
    proxies = Enum.reject(proxies, &is_nil/1)
    %__MODULE__{proxies: proxies}
  end

  def new(%Proxy{} = proxy) do
    new([proxy])
  end
end
