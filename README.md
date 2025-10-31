# Ecto Predicates

`Predicates.PredicateConverter` converts rich JSON-based predicates into ecto queries. It is aware of an ecto model's
fields and associations to achieve powerful querying capabilities in a data-driven manner.

The use case of this library is to give users the power to define an expected set of results from an operation.

## Introduction

Predicates are JSON objects of a specific shape. Every predicate requires the keys `op` and `arg`/`args` and
many operations also require a `path` to work on. They express an assertion about objects in a database.

For example, the following predicate constrains a query to `Model` objects with `type_id` equal to
`062e602a-3c38-46a3-b463-237e3767a5aa`.

```elixir
predicate = %{
  "op" => "eq",
  "path" => "type_id",
  "arg" => "062e602a-3c38-46a3-b463-237e3767a5aa"
}

from(Model, as: models)
|> PredicateConverter.convert(predicate)
|> Repo.all()
```

Combine predicates using `and`/`or`, use different operators and walk associations to build more complex predicates:

```json
{
  "op": "or",
  "args": [
    {
      "op": "eq",
      "path": "type_id",
      "arg": "062e602a-3c38-46a3-b463-237e3767a5aa"
    },
    {
      "op": "in",
      "path": "zone_id",
      "arg": ["zone_1", "zone_2"]
    },
    {
      "op": "and",
      "args": [
        {
          "op": "ilike",
          "path": "single_assoc.name",
          "arg": "Some Query String"
        },
        {
          "op": "any",
          "path": "multi_association",
          "arg": {
            "op": "eq",
            "path": "settings.nested.key",
            "arg": "associate-id-0815"
          }
        }
      ]
    }
  ]
}
```

## Operators

### Operator Overview

- Generic Comparators
  - `eq`: Value at `path` equals `arg`
  - `not_eq`: Value at `path` not equals `arg`
- Numeric Comparators
  - `lt`: Value at `path` is less than `arg`
  - `le`: Value at `path` is less than or equal to `arg`
  - `gt`: Value at `path` is greater than `arg`
  - `ge`: Value at `path` is greater than or equal to `arg`
- String Comparators
  - `like`: Value at `path` contains `arg`, case sensitive
  - `ilike`: Value at `path` contains `arg`, case insensitive
  - `starts_with`: Value at `path` starts with `arg`, case sensitive
  - `end_width`: Value at `path` ends with `arg`, case sensitive
- List Comparators
  - `in`: (Single) value at `path` is in the (multiple) values of `arg`
  - `not_in`: (Single) value at `path` is not in the (multiple) values of `arg`
- Conjunctions
  - `and`: Combines multiple predicates s.t. all of them must be fulfilled
  - `or`: Combines multiple predicates s.t. one of them must be fulfilled
- Negation
  - `not`: Negates a sub-predicate
- Quantor
  - `any`: Sub-predicate matches for any of the associated entities

### Generic Comparators: `eq` & `not_eq`

Evaluates to true if the stored value exactly matches/doesn't match the provided argument. These operators are null-safe, see [Null Values](#null-values).

#### Params

- **`op`**: `eq` | `not_eq`
- **`path`** _`String`_: The field name or the path
- **`arg`** _`String | Number | Boolean | null`_: The value to compare the stored data against

#### Example

```json
{
  "op": "eq",
  "path": "assettype_id",
  "arg": "062e602a-3c38-46a3-b463-237e3767a5aa"
}
```

### Numeric Comparators: `gt`, `ge`, `lt` & `le`

Evaluates to true if the stored value is greater than (`gt`)/greater than or equal (`ge`)/less than (`lt`)/less than or equal (`le`) the provided argument. These operators are **not** null-safe, see [Null Values](#null-values).

The comparator uses the database's comparators `<`, `<=`, `>` & `>=`.

If `path` points to a model field with of either `:utc_datetime` or `:utc_datetime_usec`, PredicateConverter annotates the `arg` to increase the compatibility of user-provided values.

#### Params

- **`op`**: `gt` | `ge` | `lt` | `le`
- **`path`** _`String`_: The field name or the path
- **`arg`** _`Number`_: The value to compare the stored value against

#### Example

```json
{
  "op": "ge",
  "path": "currstate.temp.val",
  "arg": 23
}
```

### String Comparators: `like`, `ilike`, `starts_with` & `ends_with`

Evaluates to true if the stored string contains (`like`)/contains ignoring casing (`ilike`)/starts with (`starts_with`)/ends with `ends_with` the provided argument. These operators are **not** null-safe, see [Null Values](#null-values).

#### Params

- **`op`**: `like` | `ilike` | `starts_with` | `ends_with`
- **`path`** _`String`_: The field name or the path
- **`arg`** _`String`_: The value to process the operation against the stored value. Placeholder characters (`%` and `_`) are escaped.

#### Example

```json
{
  "op": "ilike",
  "path": "assettype.name",
  "arg": "PartOfTypeName"
}
```

### List Comparators: `in` & `not_in`

Evaluates to true if the stored value is included in (`in`)/is not included in (`not_in`) the list of provided arguments. These operators are null-safe, see [Null Values](#null-values).

#### Params

- **`op`**: `in` | `not_in`
- **`path`** _`String`_: The field name or the path
- **`arg`** _`(String | Number | Boolean | null)[]`_: The list of values to test against the stored value. Non-list arg values are wrapped automatically.

##### Example

```json
{
  "op": "in",
  "path": "type_id",
  "arg": [
    "062e602a-3c38-46a3-b463-237e3767a5aa",
    "4fe40528-aeba-48b3-b1e0-9eebed63f1a0"
  ]
}
```

#### Contains Comparator: `contains`

**Deprecation**: Using `contains` with string values is deprecated, use `like` instead.

Compare operation to check if a stored value or a list of values contains a single or a list of values.
In case of a simple stored value it'll fallback to a basic string comparator.
If the stored value is a json the postgres [containment operators](https://www.postgresql.org/docs/current/datatype-json.html#JSON-CONTAINMENT) are applied.

**Params:**

- **`op`**: `contains`
- **`path`** _`String`_: The field name or the path
- **`arg`** _`String | String[]`_: The list of values to test against the stored value.

**Example:**

```json
{
  "op": "contains",
  "path": "meta.tags",
  "arg": ["facility_a", "in_transit"]
}
```

#### Conjunction Operators: `and` & `or`

Evaluates to true when all (`and`)/any (`or`) sub-predicates are true.

When given an empty list for `args`, `and` evaluates to true, while `or` evaluates to false.

#### Params

- **`op`**: `and` | `or`
- **`args`** _`Predicate[]`_: The list of predicates to combine

#### Example

```json
{
  "op": "or",
  "args": [
    {
      "op": "eq",
      "path": "type_id",
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

### Negation Operator: `not`

Evaluates to true when the sub-predicate is false.
For operators that define an inverse operation (e.g. `eq` & `not_eq`, `in` & `not_in`), prefer using those to avoid unexpected results if null values are involved, see [Null Values](#null-values).

#### Params

- **`op`**: `not`
- **`arg`** _`Predicate`_: A sub-predicate to invert

#### Example

```json
{
  "op": "not",
  "arg": {
    "op": "eq",
    "path": "type_id",
    "arg": "062e602a-3c38-46a3-b463-237e3767a5aa"
  }
}
```

### Quantor Operator: `any`

Evaluates to true if the sub-predicate is true for any of the associated entities.
The `any` operator is also implicitly introduced when walking a 1-to-many association using `.`-path notation, see [Path Resolution](#path-resolution).

The sub-predicate is evaluated within the scope of the target entity, meaning that a path of `""` targets the relationship destination itself, and `"id"` targets the `id` column of the related entity.

#### Params

- **`op`**: `any`
- **`path`** _`String`_: The field name holding the associated data
- **`arg`** _`Predicate`_: A sub-predicate to process against the associated data

#### Example

```json
{
  "op": "any",
  "path": "uploads",
  "arg": {
    "op": "eq",
    "path": "id",
    "arg": "062e602a-3c38-46a3-b463-237e3767a5aa"
  }
}
```

## <a id="null-values"></a> Null Values

In SQL, handling NULL values can lead to unexpected situations, as the result of comparisons with NULL are always NULL and thus falsy. For example, a simple _equals_ check `field = 'foo'` is false if `field` is NULL, but `field != 'foo'` is also false.

This library tries handling this circumstance by adding the appropriate comparisons to the underlying query, and is particularly relevant to `not_eq` and `not_in` (which would incorrectly omit results if not taken care of).

However, this special handling is not applied when negating `eq` or `in` through `not`. For example, the following two predicates are not the same (if NULL values are involved), because `not_eq` does include record with `type_id IS NULL`, while `not` with `eq` doesn't.

```json
{
  "op": "not_eq",
  "path": "type_id",
  "arg": "38d5f5b4-d2f0-5ef6-b72c-b69d49196b11"
}
// not the same if NULL values are involved:
{
  "op": "not",
  "arg": {
    "op": "eq",
    "path": "type_id",
    "arg": "38d5f5b4-d2f0-5ef6-b72c-b69d49196b11"
  }
}
```

If operators are not stated as being _null-safe_, then there is no special treatment of NULL values for those operators.

## <a id="model-awareness"></a> Model Awareness

PredicateConverter requires an ecto schema as a basis for predicate conversion. To avoid ambiguity with joins etc., it requires the original model query to be a named binding in accordance to the schema's table name.

For example, applying PredicateConverter to the following schema (`PredicateConvert.build_query(MyModel, predicate)`) results in a binding named `:my_models` being created.

```elixir
defmodule MyModel do
  use Ecto.Schema

  schema "my_models" do
    field :foo, :string
  end
end
```

This is important if an existing query is passed to `build_query/3` – in case the binding already has a different name, PredicateConverter tries to apply the table name which results in an error.

Also, [Virtual Fields](#virtual-fields) need to refer to the binding name if using subqueries to compute data.

## <a id="path-resolution"></a> Path Resolution

Operators compare user provided values against stored values, which are resolved by the `path` argument.
A path is a string consisting of key(s) joined by a dot (`.`) deliminator.
PredicateConverter splits a path into segments and resolves them step-by-step in a model-aware manner.

_Note: due to the path syntax, single keys cannot contain dot characters._

The first path segment is converted to atom and looked-up on the model:

1. If no field is defined, an error is raised.
2. If the field is stored and of type `:map`, there must be further path segments which are ultimately used to look up values within the JSON structure.
3. If the field is stored, its value is used for the comparison. The remaining path is discarded.
4. If the field is a virtual field, PredicateConverter invokes `get_virtual_field` as described in [Virtual Fields](#virtual-fields). The remaining path is discarded.
5. If the segment points to an association, an `any` predicate is created with the semantics of "is there a related entity for which the original predicate evaluates to true?". This behaves the same for both one-to-one and one-to-many relationships. The remaining path is applied to the related entity.

## <a id="virtual-fields"></a> Virtual Fields

Virtual fields in Ecto are fields defined in your schema that do not exist in the database (`virtual: true`). They are useful for computed or derived values, such as combining multiple columns, formatting data, or performing temporary calculations.

To allow PredicateConverter to use virtual fields, the schema module must implement a `get_virtual_field/2` (or `/1`) returning a query fragment that evaluates to a value.

When using sub-queries, refer to to the parent query using the named binding from [Model Awareness](#model-awareness).

The following example shows how the oldest post date (from the schema `Post`) for a given author is computed in a subquery. It also shows how the original query's fields may be used in addition.

```elixir
defmodule Author do
  use Ecto.Schema

  schema "authors" do
    # fields …

    field :oldest_post_date, :datetime_utc, virtual: true
  end

  def get_virtual_field(:oldest_post_date, original_query), do:
    dynamic(
      subquery(
        from(p in Post,
          where: p.author_id == parent_as(:authors).id and
            p.publisher == original_query["publisher"],
          order_by: [asc: p.inserted_at],
          limit: 1,
          select: p.inserted_at
        )
      )
    )
end
```

## Multi-Tenancy

Multi-tenancy is not enforced by default. When using "soft multi tenancy" (where data is stored in shared tables and
isolation is achieved by filtering), PredicateConverter supports maintaining tenant isolation when walking associations
(see [Path Resolution](#path-resolution)) under the following conditions:

- Within the association's target schema module, a `client_query_key/0` must be defined to return the atom key of a field that is used for filtering by tenant, e.g. `:client_id`.
- `PredicateConverter.build_query/3` must be called with a third argument, typically the user's raw query, that contains a `"client_id"` entry.

As a result, PredicateConverter will (on any given association) add an additional WHERE clause that restricts the field `client_query_key` to the value of `"client_id"` from the third argument.

_Note: this only applied to associations accessed through PredicateConverter. The caller is responsible for applying the appropriate filters for the root query (tenant isolation and other domain requirements)._

## Limitations

### Compatibility

This library was implemented targeting PostgreSQL and uses JSON path or array containment operators that might be
incompatible with other databases. Please feel free to contribute!

### Accidental Exposure of Information

When accepting untrusted query predicates, third parties might be able to access information on the model itself or
associated records that would otherwise not be exposed to them.

For example, users could guess the value of an otherwise hidden field by systematically issuing queries such as:

```json
{
  "op": "gt",
  "path": "hidden_grade",
  "arg": 3.5
}
```

### Unlimited Predicate Complexity

The library does not calculate or limit the total complexity of the given predicate at the moment.
When evaluating untrusted query predicates, this can potentially lead to unexpected or excessive resource usage on the database.

## Installation

The package can be installed by adding `ecto_predicates` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_predicates, "~> 0.1.0"}
  ]
end
```

## Run Tests

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
