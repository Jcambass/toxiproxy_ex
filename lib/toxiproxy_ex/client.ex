defmodule ToxiproxyEx.Client do
  @moduledoc false

  alias Tesla.Env
  alias ToxiproxyEx.ServerError

  @spec request!(:get | :post | :delete, String.t(), map() | nil) :: response_body :: term()
  def request!(method, path, params \\ nil)
      when method in [:get, :post, :delete] and is_binary(path) and
             (is_nil(params) or is_map(params)) do
    middlewares = [
      {Tesla.Middleware.BaseUrl, Application.fetch_env!(:toxiproxy_ex, :host)},
      Tesla.Middleware.JSON
    ]

    client = Tesla.client(middlewares, {Tesla.Adapter.Mint, []})

    request_opts = [method: method, url: path]
    request_opts = if params, do: Keyword.put(request_opts, :body, params), else: request_opts

    case Tesla.request(client, request_opts) do
      {:ok, %Env{status: status, body: body}} when status in 200..299 ->
        body

      {:ok, %Env{} = env} ->
        raise ServerError, method: method, path: path, reason: {:status, env}

      {:error, {Tesla.Middleware.JSON, :decode, %Jason.DecodeError{} = error}} ->
        raise ServerError, method: method, path: path, reason: error

      {:error, reason} ->
        raise ServerError, method: method, path: path, reason: reason
    end
  end
end
