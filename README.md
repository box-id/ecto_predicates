# PredicateToEctoConverter

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `predicate_to_ecto_converter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:predicate_to_ecto_converter, "~> 0.1.0"}
  ]
end

 defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/predicate_to_ecto_converter>.

