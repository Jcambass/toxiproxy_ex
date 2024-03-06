# ToxiproxyEx

[![github.com](https://github.com/Jcambass/toxiproxy_ex/workflows/.github/workflows/main.yml/badge.svg)](https://github.com/Jcambass/toxiproxy_ex/actions)
[![hex.pm](https://img.shields.io/hexpm/v/toxiproxy_ex.svg)](https://hex.pm/packages/toxiproxy_ex)
[![hexdocs.pm](https://img.shields.io/badge/api-docs-lightgreen.svg)](https://hexdocs.pm/toxiproxy_ex/api-reference.html)
[![hex.pm](https://img.shields.io/hexpm/dt/toxiproxy_ex.svg)](https://hex.pm/packages/toxiproxy_ex)
[![hex.pm](https://img.shields.io/hexpm/l/toxiproxy_ex.svg)](https://hex.pm/packages/toxiproxy_ex)
[![github.com](https://img.shields.io/github/last-commit/Jcambass/toxiproxy_ex.svg)](https://github.com/Jcambass/toxiproxy_ex/commits/main)

<!-- MDOC !-->

ToxiproxyEx is an Elixir API client for the resilience testing tool Toxiproxy.

[Toxiproxy](https://github.com/shopify/toxiproxy) is a proxy to simulate network
and system conditions. The Elixir API aims to make it simple to write tests that
ensure your application behaves appropriately under harsh conditions. Before you
can use the Elixir library, you need to read the [Usage section of the Toxiproxy
README](https://github.com/shopify/toxiproxy#usage).

## Usage

By default the Elixir client communicates with the Toxiproxy daemon via HTTP on `http://127.0.0.1:8474`, but you can point to any host via your application configuration:
```elixir
config :toxiproxy_ex, host: "http://toxiproxy.local:8844"
```

For example, to simulate 1000ms latency on a database server you can use the
`latency` toxic with the `latency` argument (see the Toxiproxy project for a
list of all toxics):

```elixir
ToxiproxyEx.get!(:mysql_master)
|> ToxiproxyEx.toxic(:latency, latency: 1000)
|> ToxiproxyEx.apply!(fn ->
  Repo.all(Shop) # this took at least 1s
end)
```

You can also take an endpoint down for the duration of a function at the TCP level:

```elixir
ToxiproxyEx.get!(:mysql_master)
|> ToxiproxyEx.down!(fn ->
  Repo.all(Shop) # this'll raise
end)
```

If you want to simulate all your Redis instances being down:

```elixir
ToxiproxyEx.grep!(~r/redis/)
|> ToxiproxyEx.down!(fn ->
  # any redis call will fail
end)
```

If you want to simulate that your cache server is slow at incoming network
(upstream), but fast at outgoing (downstream), you can apply a toxic to just the
upstream:

```elixir
ToxiproxyEx.get!(:cache)
|> ToxiproxyEx.upstream(:latency, latency: 1000)
|> ToxiproxyEx.apply!(fn ->
  Cache.get(:omg) # will take at least a second
end)
```

By default the toxic is applied to the downstream connection, you can be
explicit and compose them:

```elixir
ToxiproxyEx.grep!(~r/redis/)
|> ToxiproxyEx.upstream(:slow_close, delay: 100)
|> ToxiproxyEx.downstream(:latency, jitter: 300)
|> ToxiproxyEx.apply!(fn ->
  # all redises are now slow at responding and closing
end)
```

See the [Toxiproxy README](https://github.com/shopify/toxiproxy#Toxics) for a
list of toxics.

## Populate

To populate Toxiproxy pass the proxy configurations to `ToxiproxyEx.populate!`:

```elixir
ToxiproxyEx.populate!([
  %{
    name: "mysql_master",
    listen: "localhost:21212",
    upstream: "localhost:3306",
  },
  %{
    name: "mysql_read_only",
    listen: "localhost:21213",
    upstream: "localhost:3306",
  }
])
```

This will create the proxies passed, or replace the proxies if they already exist in Toxiproxy.
It's recommended to do this as early in your application startup process as possible, see the
[Toxiproxy README](https://github.com/shopify/toxiproxy#usage). If you have many
proxies, we recommend storing the Toxiproxy configs in a configuration file and
deserializing it into `ToxiproxyEx.populate!/1`.

## Error Handling

This library made the choice to use exceptions on the public API methods to signal errors.

This was chosen since this is a library meant to be used in testing code only, where you want test cases to fail if your set assumptions are not met. In this sense setting assumptions that will not be met (toxiproxy-server is not running, passing invalid configurations) is considered to be a developer error and should be fixed rather than handled in code.

**Server Errors**

If any API interaction with toxiproxy fails, a `ServerError` will be raised.

**Client Errors**

If you miss-configure toxiproxy via the elixir API, an `ArgumentError` will be raised.

<!-- MDOC !-->

## Installation

The package can be installed
by adding `toxiproxy_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:toxiproxy_ex, "~> 2.0.0", only: :test}
  ]
end
```

## Running tests

Clone the repo and fetch its dependencies:

    $ git clone https://github.com/jcambass/toxiproxy_ex.git
    $ cd toxiproxy_ex
    $ mix deps.get

Make sure that you have [Toxiproxy](https://github.com/Shopify/toxiproxy) installed and start it:

    $ toxiproxy-server

Run tests:

    $ mix test
