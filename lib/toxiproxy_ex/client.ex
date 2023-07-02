defmodule ToxiproxyEx.Client do
  @moduledoc false

  def reset() do
    url("/reset")
    |> Req.post(json: %{})
  end

  def version() do
    url("/version")
    |> Req.get()
  end

  def list_proxies() do
    url("/proxies")
    |> Req.get()
  end

  def create_proxy(params) do
    url("/proxies")
    |> Req.post(json: params)
  end

  def destroy_proxy(name) do
    url("/proxies/#{name}")
    |> Req.delete()
  end

  def enable_proxy(name) do
    url("/proxies/#{name}")
    |> Req.post(json: %{enabled: true})
  end

  def disable_proxy(name) do
    url("/proxies/#{name}")
    |> Req.post(json: %{enabled: false})
  end

  def list_toxics(proxy_name) do
    url("/proxies/#{proxy_name}/toxics")
    |> Req.get()
  end

  def create_toxic(proxy_name, params) do
    url("/proxies/#{proxy_name}/toxics")
    |> Req.post(json: params)
  end

  def destroy_toxic(proxy_name, toxic_name) do
    url("/proxies/#{proxy_name}/toxics/#{toxic_name}")
    |> Req.delete()
  end

  defp url(path) do
    Application.get_env(:toxiproxy_ex, :host, "http://127.0.0.1:8474") <> path
  end
end
