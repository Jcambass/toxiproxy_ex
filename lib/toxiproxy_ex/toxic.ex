defmodule ToxiproxyEx.Toxic do
  @moduledoc false

  alias ToxiproxyEx.Client

  @typedoc since: "1.2.0"
  @type t() :: %__MODULE__{}

  defstruct [
    :type,
    :name,
    :stream,
    :proxy_name,
    :attributes,
    :toxicity
  ]

  @spec new(keyword()) :: t()
  def new(fields) when is_list(fields) do
    fields =
      fields
      |> maybe_put_default(:toxicity, 1.0)
      |> maybe_put_default(:stream, "downstream")
      |> maybe_put_default(:name, fn fields ->
        "#{Keyword.get(fields, :type)}_#{Keyword.get(fields, :stream)}"
      end)
      |> Keyword.update!(:attributes, fn attrs ->
        Enum.into(attrs, %{})
      end)

    struct!(__MODULE__, fields)
  end

  defp maybe_put_default(fields, field, default_or_fun) do
    if Keyword.get(fields, field) do
      fields
    else
      put_default(fields, field, default_or_fun)
    end
  end

  defp put_default(fields, field, fun) when is_function(fun) do
    Keyword.put(fields, field, fun.(fields))
  end

  defp put_default(fields, field, default) do
    Keyword.put(fields, field, default)
  end

  @spec create(t()) :: {:ok, t()} | :error
  def create(%__MODULE__{} = toxic) do
    body = %{
      name: toxic.name,
      type: toxic.type,
      stream: toxic.stream,
      toxicity: toxic.toxicity,
      attributes: toxic.attributes
    }

    case Client.request(:post, "/proxies/#{toxic.proxy_name}/toxics", body) do
      {:ok, %{"attributes" => attributes, "toxicity" => toxicity}} ->
        # Note: We update attributes and toxicity to ensure that our local representation is as close as possible to the data on the server.
        # We do not make use of those fields after `create` has been called but we update them anyway.
        {:ok,
         new(
           name: toxic.name,
           type: toxic.type,
           stream: toxic.stream,
           toxicity: toxicity,
           attributes: attributes,
           proxy_name: toxic.proxy_name
         )}

      {:error, _reason} ->
        :error
    end
  end

  @spec destroy(t()) :: :ok | :error
  def destroy(%__MODULE__{} = toxic) do
    case Client.request(:delete, "/proxies/#{toxic.proxy_name}/toxics/#{toxic.name}") do
      {:ok, _body} -> :ok
      {:error, _reason} -> :error
    end
  end
end
