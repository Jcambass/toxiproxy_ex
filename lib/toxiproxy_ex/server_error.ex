defmodule ToxiproxyEx.ServerError do
  @moduledoc """
  Raised when communication with the Toxiproxy server fails.
  """

  @typedoc since: "1.2.0"
  @type t() :: %__MODULE__{
          message: String.t()
        }

  defexception message: "Server Error"

  @impl true
  def exception(options) when is_list(options) do
    method = Keyword.fetch!(options, :method)
    path = Keyword.fetch!(options, :path)
    reason = Keyword.fetch!(options, :reason)

    string_reason =
      case reason do
        {:status, %Tesla.Env{status: status, headers: headers, body: body}} ->
          """
          invalid status code #{status}.

            Headers: #{inspect(headers)}
            Body: #{inspect(body)}

          """

        %Jason.DecodeError{} = error ->
          Exception.message(error)

        other ->
          inspect(other)
      end

    message = """
    Request to the Toxiproxy server failed.

    Request: #{method |> to_string() |> String.upcase()} #{path}
    Failure reason: #{string_reason}
    """

    %__MODULE__{message: message}
  end
end
