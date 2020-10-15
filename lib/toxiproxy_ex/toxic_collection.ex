defmodule ToxiproxyEx.ToxicCollection do
  @moduledoc false

  defstruct proxies: [], toxics: []

  def new(proxies) when is_list(proxies) do
    proxies = Enum.reject(proxies, &is_nil/1)
    %__MODULE__{proxies: proxies}
  end

  def new(proxy) do
    new([proxy])
  end
end
