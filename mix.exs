defmodule ToxiproxyEx.MixProject do
  use Mix.Project

  @source_url "https://github.com/Jcambass/toxiproxy_ex"

  def project do
    [
      app: :toxiproxy_ex,
      version: "1.1.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: "Elixir Client for Toxiproxy",
      package: package(),

      # Docs
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:tesla, "~> 1.3.0"},
      {:jason, ">= 1.0.0"},
      {:castore, "~> 0.1.0"},
      {:mint, "~> 1.0"},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Joel Colin Ambass"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "GitHub" => @source_url
      },
      files: ~w(.formatter.exs mix.exs README.md CHANGELOG.md lib)
    ]
  end

  defp docs do
    [
      main: "ToxiproxyEx",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
