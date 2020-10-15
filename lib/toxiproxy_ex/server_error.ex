defmodule ToxiproxyEx.ServerError do
  @moduledoc """
  Raised when communication with the toxiproxy server fails.
  """
  defexception message: "Server Error"
end
