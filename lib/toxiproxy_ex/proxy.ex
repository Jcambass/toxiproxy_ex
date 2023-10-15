defmodule ToxiproxyEx.Proxy do
  @moduledoc false

  alias ToxiproxyEx.{Client, Toxic}

  @typedoc since: "1.2.0"
  @type t() :: %__MODULE__{
          upstream: String.t(),
          listen: String.t(),
          name: String.t(),
          enabled: boolean()
        }

  defstruct upstream: nil, listen: nil, name: nil, enabled: nil

  @spec disable(t()) :: :ok
  def disable(%__MODULE__{} = proxy) do
    Client.request!(:post, "/proxies/#{proxy.name}", %{enabled: false})
    :ok
  end

  @spec enable(t()) :: :ok
  def enable(%__MODULE__{} = proxy) do
    Client.request!(:post, "/proxies/#{proxy.name}", %{enabled: true})
    :ok
  end

  @spec create(keyword()) :: t()
  def create(options) when is_list(options) do
    upstream = Keyword.get(options, :upstream)
    listen = Keyword.get(options, :listen, "localhost:0")
    name = Keyword.get(options, :name)
    enabled = Keyword.get(options, :enabled)

    body = %{
      upstream: upstream,
      name: name,
      listen: listen,
      enabled: enabled
    }

    %{"listen" => listen, "enabled" => enabled, "name" => name} =
      Client.request!(:post, "/proxies", body)

    %__MODULE__{upstream: upstream, listen: listen, name: name, enabled: enabled}
  end

  @spec destroy(t()) :: :ok
  def destroy(%__MODULE__{} = proxy) do
    Client.request!(:delete, "/proxies/#{proxy.name}")
    :ok
  end

  @spec toxics(t()) :: [Toxic.t()]
  def toxics(%__MODULE__{} = proxy) do
    toxics = Client.request!(:get, "/proxies/#{proxy.name}/toxics")
    Enum.map(toxics, &parse_toxic(&1, proxy))
  end

  defp parse_toxic(
         %{
           "type" => type,
           "name" => name,
           "stream" => stream,
           "toxicity" => toxicity,
           "attributes" => attributes
         },
         proxy
       ) do
    Toxic.new(
      type: type,
      name: name,
      proxy_name: proxy.name,
      stream: stream,
      toxicity: toxicity,
      attributes: attributes
    )
  end
end
