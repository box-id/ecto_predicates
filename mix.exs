defmodule PredicateToSQL.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_predicates,
      version: "0.4.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def cli do
    [preferred_envs: ["test.watch": :test]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.12"},
      {:ok, "~> 2.3.0"},
      {:plug, "~> 1.10", optional: true},
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
