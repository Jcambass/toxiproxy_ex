defmodule ToxiproxyEx.ServerError do
  @moduledoc """
  Raised when communication with the toxiproxy server fails.
  """

  @typedoc since: "1.2.0"
  @type t() :: %__MODULE__{
    message: String.t()
  }

  defexception message: "Server Error"
end
