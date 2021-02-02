defmodule ToxiproxyEx.Client do
  @moduledoc false

  def reset() do
    client()
    |> Tesla.post("/reset", %{})
  end

  def version() do
    client()
    |> Tesla.get("/version")
  end

  def list_proxies() do
    client()
    |> Tesla.get("/proxies")
  end

  def create_proxy(params) do
    client()
    |> Tesla.post("/proxies", params)
  end

  def destroy_proxy(name) do
    client()
    |> Tesla.delete("/proxies/#{name}")
  end

  def enable_proxy(name) do
    client()
    |> Tesla.post("/proxies/#{name}", %{enabled: true})
  end

  def disable_proxy(name) do
    client()
    |> Tesla.post("/proxies/#{name}", %{enabled: false})
  end

  def list_toxics(proxy_name) do
    client()
    |> Tesla.get("/proxies/#{proxy_name}/toxics")
  end

  def create_toxic(proxy_name, params) do
    client()
    |> Tesla.post("/proxies/#{proxy_name}/toxics", params)
  end

  def destroy_toxic(proxy_name, toxic_name) do
    client()
    |> Tesla.delete("/proxies/#{proxy_name}/toxics/#{toxic_name}")
  end

  defp client() do
    url = Application.get_env(:toxiproxy_ex, :host, "http://127.0.0.1:8474")

    middleware = [
      {Tesla.Middleware.BaseUrl, url},
      Tesla.Middleware.JSON
    ]

    adapter = {Tesla.Adapter.Mint, []}

    Tesla.client(middleware, adapter)
  end
end
