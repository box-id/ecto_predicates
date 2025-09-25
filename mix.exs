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

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.10"},
      {:ecto_sql, "~> 3.12"},
      {:assertions, "~> 0.20", only: [:dev, :test]},
      {:ok, "~> 2.3.0"},
      {:postgrex, "~> 0.15"},
      {:jason, "~> 1.2"},
      {:ecto_enum, "~> 1.4"}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end
end
