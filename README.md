# Ecto Predicates

Predicates are complex database queries defined as json.

A predicate is a JSON Object with the required keys `op` and `arg` and for certain operations the key `path` is also required.

**⚠️ This module is implemented using the ecto postgrex module**

For example:

```json
{
  "op": "eq",
  "path": "assettype_id",
  "arg": "062e602a-3c38-46a3-b463-237e3767a5aa"
}
```

**Complex Example:**

```json
{
  "op": "or",
  "args": [
    {
      "op": "in",
      "path": "assettype_id",
      "arg": [
        "062e602a-3c38-46a3-b463-237e3767a5aa",
        "4fe40528-aeba-48b3-b1e0-9eebed63f1a0"
      ]
    },
    {
      "op": "ilike",
      "path": "name",
      "arg": "NamePart"
    },
    {
      "op": "in",
      "path": "zonetree_id",
      "arg": [
        "6a1c62fd-424d-4e33-a569-5ffabdc7cba7",
        "a9897811-1d9d-4cf7-89a5-f3b0d530687b"
      ]
    },
    {
      "op": "and",
      "args": [
        {
          "op": "ilike",
          "path": "tokens.token",
          "arg": "special-token"
        },
        {
          "op": "eq",
          "path": "asset_labels.label",
          "arg": "in-use-label"
        },
        {
          "op": "any",
          "path": "asset_associates",
          "arg": {
            "op": "eq",
            "path": "asset_labels.associate_id",
            "arg": "associate-id-0815"
          }
        }
      ]
    }
  ]
}
```

### Possible Operations are:

#### Comparator Predicate:

Exact compare of a argument against a stored value

**Params:**

- **`op`** _`String` enum: `eq`_: The operation for an exact compare
- **`path`** _`String`_: The field name or the path to the key. This can be a path inside a json field or the path through connected/related tables
- **`arg`** _`String | Number | Boolean`_: The value to compare the stored data against

**Simple Example:**

```json
{
  "op": "eq",
  "path": "assettype_id",
  "arg": "062e602a-3c38-46a3-b463-237e3767a5aa"
}
```

#### Numeric Comparator Predicates:

Execute a numeric compare operation of a value against a stored value.

**Params:**

- **`op`** _`String` enum: `gt` | `gte` | `lt` | `lte`_: The operation for the numeric compare
  - _`gt`_: Greater than
  - _`gte`_: Greater or equal than
  - _`lt`_: Lower than
  - _`lte`_: Lower or equal than
- **`path`** _`String`_: The field name or the path to the key. This can be a path inside a json field or the path through connected/related tables
- **`arg`** _`Number`_: The value to process the operation against the stored value

**Example:**

```json
{
  "op": "gte",
  "path": "currstate.temp.val",
  "arg": 23
}
```

#### String Comparator Predicates:

Execute a sting search operation of a value against a stored value.

**Params:**

- **`op`** _`String` enum: `like` | `ilike` _: The operation for the string based compare operations
  - _`like`_: Case sensitive test if parts of the `arg` are contained within the stored value
  - _`ilike`_: Case insensitive test if parts of the `arg` are contained within the stored value
- **`path`** _`String`_: The field name or the path to the key. This can be a path inside a json field or the path through connected/related tables
- **`arg`** _`String`_: The value to process the operation against the stored value

**Example:**

```json
{
  "op": "ilike",
  "path": "assettype.name",
  "arg": "PartOfTypeName"
}
```

#### List Comparator Predicates:

Compare operation to check if (ot not) a value is part of a given list

**Params:**

- **`op`** _`String` enum: `in` | `not_in` _: The operation to test if one of the given values in args exactly/not exists matches the stored value
  - _`in`_: check if the stored value is within the list in `arg`
  - _`not_in`_: check if the stored value is NOT within the list in `arg`
- **`path`** _`String`_: The field name or the path to the key. This can be a path inside a json field or the path through connected/related tables
- **`arg`** _`String[]`_: The list of values to test against the stored value

**Example:**

```json
{
  "op": "in",
  "path": "assettype_id",
  "arg": [
    "062e602a-3c38-46a3-b463-237e3767a5aa",
    "4fe40528-aeba-48b3-b1e0-9eebed63f1a0"
  ]
}
```

#### Contains Comparator Predicates:

Compare operation to check if a stored value or a list of values contains a single or a list of values.
In case of a simple stored value it'll fallback to a basic string comparator.
If the stored value is a json the postgres [containment operators](https://www.postgresql.org/docs/current/datatype-json.html#JSON-CONTAINMENT) are applied.

**Params:**

- **`op`** _`String` enum: `contains`_: The operation to test if the given single or all given values as list are existent in the stored value or list of values.
- **`path`** _`String`_: The field name or the path to the key. This can be a path inside a json field or the path through connected/related tables
- **`arg`** _`String | String[]`_: The list of values to test against the stored value.

**Example:**

```json
{
  "op": "contains",
  "path": "meta.tags",
  "arg": ["facility_a", "in_transit"]
}
```

#### Junctor Predicate:

To build complex query with specific "and" and "or" conditions it's possible to nest predicates.

**Params:**

- **`op`** _`String` enum: `and` | `or`_: The junctor operation to process the nested predicates in `arg`
- **`args`** _`Predicate[]`_: The list of predicates to combine with a `and` or `or` predicate

**Example:**

```json
{
  "op": "or",
  "args": [
    {
      "op": "eq",
      "path": "assettype_id",
      "arg": "062e602a-3c38-46a3-b463-237e3767a5aa"
    },
    {
      "op": "ilike",
      "path": "assettype.name",
      "arg": "PartOfTypeName"
    }
  ]
}
```

#### Negation Predicate:

Invert the results of a sub predicate

**Params:**

- **`op`** _`String` enum: `not`_: The operation to invert a sub predicate
- **`arg`** _`Predicate`_: A sub predicate to invert

**Example:**

```json
{
  "op": "not",
  "arg": {
    "op": "eq",
    "path": "assettype_id",
    "arg": "062e602a-3c38-46a3-b463-237e3767a5aa"
  }
}
```

#### Quantor Predicate:

A predicate to look into values of associated data.

**Params:**

- **`op`** _`String` enum: `any`_: The operation to traverse into associates sub data. Identical to using a dot separated path
- **`path`** _`String`_: The field name holding the associated data.
- **`arg`** _`Predicate`_: A sub predicate to process against the associated sub data. Here the current `path` of this any predicate is no longer relevant and the sub predicate has to use the fields of the associated schema directly

**Example:**

```json
{
  "op": "any",
  "path": "assettype",
  "arg": {
    "op": "eq",
    "path": "id",
    "arg": "062e602a-3c38-46a3-b463-237e3767a5aa"
  }
}
```

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
