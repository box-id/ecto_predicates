defmodule PredicateToEctoConverter.MixProject do
  use Mix.Project

  def project do
    [
      app: :predicate_to_ecto_converter,
      version: "0.1.0",
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
      {:ecto_sql, "~> 3.11.0"},
      {:assertions, "~> 0.20", only: [:dev, :test]},
      {:ok, "~> 2.3.0"},
      {:postgrex, "~> 0.15"},
      {:jason, "~> 1.2"},
      {:ecto_network, "~> 1.3"},
      {:ecto_enum, "~> 1.4"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end
end
