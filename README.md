# Ecto Predicates

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ecto_predicates` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_predicates, "~> 0.1.0"}
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
be found at <https://hexdocs.pm/ecto_predicates>.

## Run Test

To run the tests, follow these steps:

1. Copy the example environment configuration file:

```sh
cp config.env.example config.env
```

2. Start the necessary services using Docker Compose:

```sh
make compose-up
```

3. Run the tests:

```sh
make test
```

We are using make here for a easier handling of the shared environment vars in `config.env`
