defmodule ToxiproxyEx.Client do
  @moduledoc false

  alias Tesla.Env

  @spec request(:get | :post | :delete, String.t(), map() | nil) ::
          {:ok, response_body :: term()} | {:error, reason :: term()}
  def request(method, path, params \\ nil)
      when method in [:get, :post, :delete] and is_binary(path) do
    middlewares = [
      {Tesla.Middleware.BaseUrl, Application.fetch_env!(:toxiproxy_ex, :host)},
      Tesla.Middleware.JSON
    ]

    client = Tesla.client(middlewares, {Tesla.Adapter.Mint, []})

    request_opts = [method: method, url: path]
    request_opts = if params, do: Keyword.put(request_opts, :body, params), else: request_opts

    case Tesla.request(client, request_opts) do
      {:ok, %Env{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Env{} = env} ->
        {:error, {:status, env}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
