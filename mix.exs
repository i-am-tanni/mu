defmodule Mu.MixProject do
  use Mix.Project

  def project do
    [
      app: :mu,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :eex],
      mod: {Mu.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:kalevala, git: "https://github.com/i-am-tanni/kalevala"},
      #{:kalevala, path: "~/Documents/Elixir/kalevala"}, # for testing
      {:ranch, "~> 1.7"},
      {:jason, "~> 1.4"},
      {:inflex, "~> 2.1"}
    ]
  end
end
