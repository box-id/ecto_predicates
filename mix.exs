defmodule Predicates.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_predicates,
      version: "0.5.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Docs
      name: "Ecto Predicates",
      source_url: "https://github.com/box-id/ecto_predicates",
      docs: &docs/0
    ]
  end

  def docs do
    [
      main: "readme",
      extras: ["README.md", "Operators.md"]
    ]
  end

  def cli do
    [preferred_envs: ["test.watch": :test]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.12"},
      {:ok, "~> 2.3.0"},
      {:plug, "~> 1.10", optional: true},
      {:ex_doc, "~> 0.39", only: :dev, runtime: false, warn_if_outdated: true},
      {:makeup_json, "~> 1.0", only: :dev},
      {:jason, "~> 1.4", only: [:dev, :test]},
      {:postgrex, "~> 0.15", only: [:dev, :test]},
      {:assertions, "~> 0.20", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end
end
