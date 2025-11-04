# Operators & Predicates

## Generic Comparators: `eq` & `not_eq`

Evaluates to true if the stored value exactly matches/doesn't match the provided argument. These operators are
null-safe, see [Null Values](README.md#null-values).

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

## Numeric Comparators: `gt`, `ge`, `lt` & `le`

Evaluates to true if the stored value is greater than (`gt`)/greater than or equal (`ge`)/less than (`lt`)/less than or
equal (`le`) the provided argument. These operators are **not** null-safe, see [Null Values](README.md#null-values).

The comparator uses the database's comparators `<`, `<=`, `>` & `>=`.

If `path` points to a model field with of either `:utc_datetime` or `:utc_datetime_usec`, PredicateConverter annotates
the `arg` to increase the compatibility of user-provided values.

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

## String Comparators: `like`, `ilike`, `starts_with` & `ends_with`

Evaluates to true if the stored string contains (`like`)/contains ignoring casing (`ilike`)/starts with
(`starts_with`)/ends with `ends_with` the provided argument. These operators are **not** null-safe, see [Null
Values](README.md#null-values).

#### Params

- **`op`**: `like` | `ilike` | `starts_with` | `ends_with`
- **`path`** _`String`_: The field name or the path
- **`arg`** _`String`_: The value to process the operation against the stored value. Placeholder characters (`%` and
  `_`) are escaped.

#### Example

```json
{
  "op": "ilike",
  "path": "assettype.name",
  "arg": "PartOfTypeName"
}
```

## List Comparators: `in` & `not_in`

Evaluates to true if the stored value is included in (`in`)/is not included in (`not_in`) the list of provided
arguments. These operators are null-safe, see [Null Values](README.md#null-values).

#### Params

- **`op`**: `in` | `not_in`
- **`path`** _`String`_: The field name or the path
- **`arg`** _`(String | Number | Boolean | null)[]`_: The list of values to test against the stored value. Non-list arg
  values are wrapped automatically.

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

Compare operation to check if a stored value or a list of values contains a single or a list of values. In case of a
simple stored value it'll fallback to a basic string comparator. If the stored value is a json the postgres [containment
operators](https://www.postgresql.org/docs/current/datatype-json.html#JSON-CONTAINMENT) are applied.

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

## Negation Operator: `not`

Evaluates to true when the sub-predicate is false. For operators that define an inverse operation (e.g. `eq` & `not_eq`,
`in` & `not_in`), prefer using those to avoid unexpected results if null values are involved, see [Null
Values](README.md#null-values).

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

## Quantor Operator: `any`

Evaluates to true if the sub-predicate is true for any of the associated entities. The `any` operator is also implicitly
introduced when walking a 1-to-many association using `.`-path notation, see [Path
Resolution](README.md#path-resolution).

The sub-predicate is evaluated within the scope of the target entity, meaning that a path of `""` targets the
relationship destination itself, and `"id"` targets the `id` column of the related entity.

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

## Plain Value Predicate

These special predicates always evaluate to true or false.

#### Params

- **`arg`**: `true` | `false`

#### Example

```json
{
  "arg": true
}
```
