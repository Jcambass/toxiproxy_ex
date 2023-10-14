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

  @spec disable(t()) :: :ok | :error
  def disable(%__MODULE__{} = proxy) do
    case Client.disable_proxy(proxy.name) do
      {:ok, _res} -> :ok
      _ -> :error
    end
  end

  @spec enable(t()) :: :ok | :error
  def enable(%__MODULE__{} = proxy) do
    case Client.enable_proxy(proxy.name) do
      {:ok, _res} -> :ok
      _ -> :error
    end
  end

  @spec create(keyword()) :: {:ok, t()} | :error
  def create(options) when is_list(options) do
    upstream = Keyword.get(options, :upstream)
    listen = Keyword.get(options, :listen, "localhost:0")
    name = Keyword.get(options, :name)
    enabled = Keyword.get(options, :enabled)

    case Client.create_proxy(%{
           upstream: upstream,
           name: name,
           listen: listen,
           enabled: enabled
         }) do
      {:ok, %{body: %{"listen" => listen, "enabled" => enabled, "name" => name}}} ->
        {:ok, %__MODULE__{upstream: upstream, listen: listen, name: name, enabled: enabled}}

      _ ->
        :error
    end
  end

  @spec destroy(t()) :: :ok | :error
  def destroy(%__MODULE__{} = proxy) do
    case Client.destroy_proxy(proxy.name) do
      {:ok, _res} -> :ok
      _ -> :error
    end
  end

  @spec toxics(t()) :: {:ok, [Toxic.t()]} | :error
  def toxics(%__MODULE__{} = proxy) do
    case Client.list_toxics(proxy.name) do
      {:ok, %{body: toxics}} -> {:ok, Enum.map(toxics, &parse_toxic(&1, proxy))}
      _ -> :error
    end
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
