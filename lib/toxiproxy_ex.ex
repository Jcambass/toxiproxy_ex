defmodule ToxiproxyEx do
  alias ToxiproxyEx.{Proxy, Client, Toxic, ToxicCollection}

  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  @typedoc """
  A proxy that intercepts traffic to and from an upstream server.
  """
  @opaque proxy :: Proxy.t()

  @typedoc """
  A collection of proxies.
  """
  @opaque toxic_collection :: ToxicCollection.t()

  @typedoc """
  A hostname or IP address including a port number, e.g. `localhost:4539`.
  """
  @type host_with_port :: String.t()

  @typedoc """
  A map containing fields required to setup a proxy. Designed to be used with `ToxiproxyEx.populate!/1`.
  """
  @type proxy_map :: %{
          required(:name) => String.t(),
          required(:upstream) => host_with_port(),
          optional(:listen) => host_with_port(),
          optional(:enabled) => true | false
        }

  @doc """
  Creates a proxy on the toxiproxy server.

  Raises `ToxiproxyEx.ServerError` if the creation fails.

  ## Examples

  Create a new proxy:
      iex> ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_master")

  Create a new proxy that listens on a specific port:
      iex> ToxiproxyEx.create!(upstream: "localhost:3306", listen: "localhost:5555", name: "test_mysql_master")

  Create a new proxy that is disabled by default:
      iex> ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_master", enabled: false)
  """
  @spec create!(
          upstream: host_with_port(),
          name: String.t() | atom(),
          listen: host_with_port() | nil,
          enabled: true | false | nil
        ) :: proxy()
  defdelegate create!(options), to: Proxy, as: :create

  @doc """
  Deletes one or multiple proxies on the toxiproxy server.

  Raises `ToxiproxyEx.ServerError` if the deletion fails.

  ## Examples

  Destroy a single proxy:
      iex> ToxiproxyEx.create!(upstream: "localhost:3456", name: :test_mysql_master)
      iex> proxy = ToxiproxyEx.get!(:test_mysql_master)
      iex> ToxiproxyEx.destroy!(proxy)
      :ok

  Destroy all proxies:
      iex> ToxiproxyEx.create!(upstream: "localhost:3456", name: :test_mysql_master)
      iex> proxies = ToxiproxyEx.all!()
      iex> ToxiproxyEx.destroy!(proxies)
      :ok
  """

  @spec destroy!(proxy() | toxic_collection()) :: :ok
  def destroy!(%Proxy{} = proxy) do
    destroy!(ToxicCollection.new(proxy))
  end

  def destroy!(%ToxicCollection{proxies: proxies}) do
    Enum.each(proxies, &Proxy.destroy/1)
  end

  @doc """
  Retrieves a proxy from the toxiproxy server.

  Raises `ToxiproxyEx.ServerError` if the proxy could not be retrieved.
  Raises `ArgumentError` if the proxy does not exist.

  ## Examples

  Retrievs a proxy:
      iex> ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_master")
      iex> ToxiproxyEx.get!(:test_mysql_master)
  """
  @spec get!(atom() | String.t()) :: proxy()
  def get!(name) when is_atom(name) or is_binary(name) do
    name = to_string(name)

    case Enum.find(all!().proxies, &(&1.name == name)) do
      nil -> raise ArgumentError, message: "Unknown proxy with name '#{name}'"
      proxy -> proxy
    end
  end

  @doc """
  Retrieves a list of proxies from the toxiproxy server where the name matches the specificed regex.

  Raises `ToxiproxyEx.ServerError` if the list of proxies could not be retrieved.
  Raises `ArgumentError` if no proxy matching the specified regex does exist.

  ## Examples

  Retrievs a proxy:
      iex> ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_master")
      iex> ToxiproxyEx.create!(upstream: "localhost:3307", name: "test_mysql_follower")
      iex> ToxiproxyEx.create!(upstream: "localhost:3308", name: "test_redis_master")
      iex> ToxiproxyEx.grep!(~r/master/)
  """
  @spec grep!(Regex.t()) :: toxic_collection()
  def grep!(%Regex{} = pattern) do
    case Enum.filter(all!().proxies, &String.match?(&1.name, pattern)) do
      proxies = [_h | _t] -> ToxicCollection.new(proxies)
      [] -> raise ArgumentError, message: "No proxies found for regex '#{pattern}'"
    end
  end

  @doc """
  Retrieves a list of all proxies from the toxiproxy server.

  Raises `ToxiproxyEx.ServerError` if the list of proxies could not be retrieved.

  ## Examples

  Retrievs a proxy:
      iex> ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_master")
      iex> ToxiproxyEx.create!(upstream: "localhost:3307", name: "test_redis_master")
      iex> ToxiproxyEx.all!()
  """
  @spec all!() :: toxic_collection()
  def all!() do
    Client.request!(:get, "/proxies")
    |> Enum.map(&parse_proxy/1)
    |> ToxicCollection.new()
  end

  defp parse_proxy(
         {_proxy_name,
          %{
            "upstream" => upstream,
            "listen" => listen,
            "name" => name,
            "enabled" => enabled
          }}
       ) do
    %Proxy{upstream: upstream, listen: listen, name: name, enabled: enabled}
  end

  @doc """
  Adds an upstream toxic to the proxy or list of proxies that will be enabled when passed to `ToxiproxyEx.apply!/2`.

  ## Examples

  Add an upstream toxic to a proxy:
      iex> proxy = ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_master")
      iex> proxies = ToxiproxyEx.upstream(proxy, :latency, latency: 1000)
      iex> ToxiproxyEx.apply!(proxies, fn ->
      ...>  # Do some testing
      ...>  nil
      ...> end)

  Add an upstream toxic to a list of proxies:
      iex> ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_master")
      iex> ToxiproxyEx.create!(upstream: "localhost:3307", name: "test_mysql_follower")
      iex> proxies = ToxiproxyEx.all!()
      iex> proxies = ToxiproxyEx.upstream(proxies, :latency, latency: 1000)
      iex> ToxiproxyEx.apply!(proxies, fn ->
      ...>  # Do some testing
      ...>  nil
      ...> end)
  """
  @spec upstream(proxy() | toxic_collection(), atom(), []) :: toxic_collection()
  def upstream(proxy_or_collection, type, attrs \\ [])

  def upstream(proxy = %Proxy{}, type, attrs) do
    upstream(ToxicCollection.new(proxy), type, attrs)
  end

  def upstream(%ToxicCollection{proxies: proxies, toxics: toxics}, type, attrs) do
    name = Keyword.get(attrs, :name)
    toxicity = Keyword.get(attrs, :toxicity)

    attrs =
      attrs
      |> Keyword.delete(:name)
      |> Keyword.delete(:toxicity)

    new_toxics =
      Enum.map(proxies, fn proxy ->
        Toxic.new(
          name: name,
          type: type,
          proxy_name: proxy.name,
          stream: :upstream,
          toxicity: toxicity,
          attributes: attrs
        )
      end)

    %ToxicCollection{proxies: proxies, toxics: toxics ++ new_toxics}
  end

  @doc """
  Alias for `ToxiproxyEx.downstream/3`.
  """
  @spec toxic(proxy() | toxic_collection(), atom(), []) :: toxic_collection()
  def toxic(proxy_or_collection, type, attrs \\ []) do
    downstream(proxy_or_collection, type, attrs)
  end

  @doc """
  Alias for `ToxiproxyEx.downstream/3`.
  """
  @spec toxicate(proxy() | toxic_collection(), atom(), []) :: toxic_collection()
  def toxicate(proxy_or_collection, type, attrs \\ []) do
    downstream(proxy_or_collection, type, attrs)
  end

  @doc """
  Adds an downstream toxic to the proxy or list of proxies that will be enabled when passed to `ToxiproxyEx.apply!/2`.

  ## Examples

  Add an downstream toxic to a proxy:
      iex> proxy = ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_master")
      iex> proxies = ToxiproxyEx.downstream(proxy, :latency, latency: 1000)
      iex> ToxiproxyEx.apply!(proxies, fn ->
      ...>  # Do some testing
      ...>  nil
      ...> end)

  Add an downstream toxic to a list of proxies:
      iex> ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_master")
      iex> ToxiproxyEx.create!(upstream: "localhost:3307", name: "test_mysql_follower")
      iex> proxies = ToxiproxyEx.all!()
      iex> proxies = ToxiproxyEx.downstream(proxies, :latency, latency: 1000)
      iex> ToxiproxyEx.apply!(proxies, fn ->
      ...>  # Do some testing
      ...>  nil
      ...> end)
  """
  @spec downstream(proxy() | toxic_collection(), atom(), []) :: toxic_collection()
  def downstream(proxy_or_collection, type, attrs \\ [])

  def downstream(proxy = %Proxy{}, type, attrs) do
    downstream(ToxicCollection.new(proxy), type, attrs)
  end

  def downstream(%ToxicCollection{proxies: proxies, toxics: toxics}, type, attrs) do
    name = Keyword.get(attrs, :name)
    toxicity = Keyword.get(attrs, :toxicity)

    attrs =
      attrs
      |> Keyword.delete(:name)
      |> Keyword.delete(:toxicity)

    new_toxics =
      Enum.map(proxies, fn proxy ->
        Toxic.new(
          name: name,
          type: type,
          proxy_name: proxy.name,
          stream: :downstream,
          toxicity: toxicity,
          attributes: attrs
        )
      end)

    %ToxicCollection{proxies: proxies, toxics: toxics ++ new_toxics}
  end

  @doc """
  Applies all toxics previously defined on the list of proxies during the duration of the given function.

  Raises `ToxiproxyEx.ServerError` if the toxics could not be enabled and disabled again on the server.

  ## Examples

  Add toxics and apply them toxic to a single proxy:
      iex> proxy = ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_master")
      iex> proxies = ToxiproxyEx.downstream(proxy, :slow_close, delay: 100)
      iex> proxies = ToxiproxyEx.downstream(proxies, :latency, jitter: 300)
      iex> ToxiproxyEx.apply!(proxies, fn ->
      ...>  # All calls to mysql master are now slow at responding and closing.
      ...>  nil
      ...> end)

  Add toxics and apply them toxic to a list of proxies:
      iex> ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_master")
      iex> ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_follower")
      iex> proxies = ToxiproxyEx.all!()
      iex> proxies = ToxiproxyEx.downstream(proxies, :slow_close, delay: 100)
      iex> proxies = ToxiproxyEx.downstream(proxies, :latency, jitter: 300)
      iex> ToxiproxyEx.apply!(proxies, fn ->
      ...>  # All calls to mysql master and follower are now slow at responding and closing.
      ...>  nil
      ...> end)
  """
  @spec apply!(toxic_collection(), (-> result)) :: result when result: var
  def apply!(%ToxicCollection{toxics: toxics}, fun) when is_function(fun, 0) do
    toxics
    |> Enum.group_by(fn %Toxic{} = toxic -> {toxic.name, toxic.proxy_name} end)
    |> Enum.each(fn
      {_name_and_proxy_name, [toxic, _other_toxic | _rest]} ->
        raise ArgumentError, """
        there are multiple toxics with the name #{inspect(toxic.name)} for proxy \
        #{inspect(toxic.proxy_name)}, please override the default name (<type>_<direction>)\
        """

      {_name_and_proxy_name, [_toxic]} ->
        :ok
    end)

    # We probably don't care about the updated toxics here but we still use
    # rather than the one passed into the function.
    toxics = Enum.map(toxics, &Toxic.create/1)

    try do
      fun.()
    after
      Enum.each(toxics, &Toxic.destroy/1)
    end
  end

  @doc """
  Takes down the proxy or the list of proxies during the duration of the given function.

  Raises `ToxiproxyEx.ServerError` if the proxy or list of proxies could not have been disabled and enabled again on the server.

  ## Examples

  Take down a single proxy:
      iex> proxy = ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_master")
      iex> ToxiproxyEx.down!(proxy, fn ->
      ...>  # Takes mysql master down.
      ...>  nil
      ...> end)

  Take down a list of proxies:
      iex> ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_master")
      iex> ToxiproxyEx.create!(upstream: "localhost:3306", name: "test_mysql_follower")
      iex> proxies = ToxiproxyEx.all!()
      iex> ToxiproxyEx.down!(proxies, fn ->
      ...>  # Takes mysql master and follower down.
      ...>  nil
      ...> end)
  """
  @spec down!(toxic_collection(), (-> any())) :: :ok
  def down!(proxy = %Proxy{}, fun) do
    down!(ToxicCollection.new(proxy), fun)
  end

  def down!(%ToxicCollection{proxies: proxies}, fun) do
    Enum.each(proxies, &Proxy.disable/1)
    fun.()
    Enum.each(proxies, &Proxy.enable/1)
  end

  @doc """
  Re-enables are proxies and disables all toxics on toxiproxy.

  Raises `ToxiproxyEx.ServerError` if the server could not have been reset.

  ## Examples

  Reset toxiproxy:
      iex> ToxiproxyEx.reset!()
      :ok
  """
  @spec reset!() :: :ok
  def reset!() do
    Client.request!(:post, "/reset", %{})
    :ok
  end

  @doc """
  Gets the version of the running toxiproxy server.

  Raises `ToxiproxyEx.ServerError` if the version could not have been fetched from the server.

  ## Examples

  Get running toxiproxy version:
      iex> ToxiproxyEx.version!()
      "2.1.2"
  """
  @spec version!() :: String.t()
  def version!() do
    case Client.request!(:get, "/version") do
      %{"version" => version} -> version
      version -> version
    end
  end

  @doc """
  Creates proxies based on the passed data.
  This is usefull to quickly create multiple proxies based on hardcoded value or values read from external sources such as a config file.

  Nonexisting proxies will be created and existing ones will be updated to match the passed data.

  Raises `ToxiproxyEx.ServerError` if the proxies could not have been created on the server.

  ## Examples

  Creating proxies:
      iex> ToxiproxyEx.populate!([
      ...>  %{name: "test_mysql_master", upstream: "localhost:5765"},
      ...>  %{name: "test_mysql_follower", upstream: "localhost:5766", enabled: false}
      ...> ])
  """
  @spec populate!([proxy_map()]) :: toxic_collection()
  def populate!(proxies) when is_list(proxies) do
    Enum.map(proxies, fn proxy_attrs ->
      name = Map.get(proxy_attrs, :name)
      upstream = Map.get(proxy_attrs, :upstream)
      listen = Map.get(proxy_attrs, :upstream)

      existing = Enum.find(all!().proxies, &(&1.name == name))

      if existing do
        if existing.upstream == upstream && existing.listen == listen do
          existing
        else
          destroy!(existing)

          Keyword.new(proxy_attrs)
          |> create!()
        end
      else
        Keyword.new(proxy_attrs)
        |> create!()
      end
    end)
    |> ToxicCollection.new()
  end
end
