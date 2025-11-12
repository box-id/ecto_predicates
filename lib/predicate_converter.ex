defmodule Predicates.PredicateConverter do
  @moduledoc """
  Converts a predicate map into an Ecto query.

  See [Ecto Predicates](README.md) for details on its capabilities and the predicate format.
  """

  import Ecto.Query
  import Predicates.SchemaHelpers
  import Predicates.Utils

  alias Predicates.PredicateError

  # Combines is_nil and "is JSON null" checks
  defmacrop is_nullish(field) do
    quote do
      is_nil(unquote(field)) or unquote(field) == fragment("'null'::jsonb")
    end
  end

  @doc """
  Filters an Ecto queryable based on the given predicate map.

  If the queryable does not already have a named binding for the table name of the schema, it will be added.

  ## Example

      queryable
      |> Predicates.PredicateConverter.build_query(%{
        "op" => "and",
        "args" => [
          %{"op" => "eq", "path" => "status", "arg" => "active"},
          %{"op" => "gt", "path" => "age", "arg" => 18}
        ]
      }, query_context)
  """
  @spec build_query(queryable :: Ecto.Queryable.t(), predicate :: map(), query :: map()) ::
          Ecto.Query.t()
  def build_query(queryable, predicate, query \\ %{})

  def build_query(queryable, predicate, query) do
    # define the table name as a named binding to be reused in the any predicate sub queries
    table_name = get_table_name(queryable)

    queryable =
      if Ecto.Query.has_named_binding?(queryable, table_name) do
        queryable
      else
        from(q in queryable, as: ^table_name)
      end

    where(queryable, ^convert_query(queryable, predicate, query))
  end

  @doc """
  Creates an query fragment based on the given predicate map that can be used in Ecto's `where()`.

  ## Example

      dynamic_query = Predicates.PredicateConverter.convert_query(queryable, %{
        "op" => "eq",
        "path" => "status",
        "arg" => "active"
      })

      queryable
      |> where(^dynamic_query)
  """
  @spec convert_query(queryable :: Ecto.Queryable.t(), predicate :: map(), query :: map()) ::
          Ecto.Query.dynamic_expr()
  def convert_query(queryable, predicate, query \\ %{})

  # Junctor Predicates
  # shorthand if arg for "and" or "or" predicates is just a single predicate
  def convert_query(queryable, %{"op" => op, "args" => sub_predicates}, query)
      when op in ["and", "or"] and is_map(sub_predicates) do
    convert_query(queryable, sub_predicates, query)
  end

  # combine predicates with an "and" operation
  def convert_query(queryable, %{"op" => "and", "args" => sub_predicates}, query) do
    Enum.reduce(sub_predicates, dynamic(true), fn sub_predicate, acc ->
      dynamic(^acc and ^convert_query(queryable, sub_predicate, query))
    end)
  end

  # combine predicates with a "or" operation
  def convert_query(queryable, %{"op" => "or", "args" => sub_predicates}, query) do
    Enum.reduce(sub_predicates, dynamic(false), fn sub_predicate, acc ->
      dynamic(^acc or ^convert_query(queryable, sub_predicate, query))
    end)
  end

  # Negation Predicate
  def convert_query(queryable, %{"op" => "not", "arg" => sub_predicates}, query) do
    dynamic(not (^convert_query(queryable, sub_predicates, query)))
  end

  # Quantor Predicate
  def convert_query(
        queryable,
        %{"op" => "any", "path" => path, "arg" => sub_predicate},
        meta
      ) do
    case process_path(queryable, path, meta) do
      {:assoc, field, _} ->
        convert_any({:assoc, field}, sub_predicate, queryable, meta)

      {:single, field} ->
        convert_any({:single, field}, sub_predicate, queryable, meta)

      {:virtual, field, {:array, :map} = type, path} ->
        convert_any({:virtual, field, type, path}, sub_predicate, queryable, meta)

      _ ->
        raise PredicateError,
          message: "Operator 'any' is not supported for this field"
    end
  end

  # Comparator Predicates
  def convert_query(queryable, %{"op" => op, "path" => path, "arg" => value} = predicate, meta) do
    path = process_path(queryable, path, meta)

    try do
      convert_comparator(op, path, value, queryable, meta)
    rescue
      FunctionClauseError ->
        # credo:disable-for-next-line Credo.Check.Warning.RaiseInsideRescue
        raise PredicateError,
          message: "Operator #{inspect(op)} not supported",
          predicate: predicate

      e ->
        reraise e, __STACKTRACE__
    end
  end

  # Value Predicate
  def convert_query(_queryable, %{"arg" => value} = predicate, _meta)
      when is_boolean(value) and map_size(predicate) == 1 do
    dynamic(^value)
  end

  # Fallback for invalid predicates
  def convert_query(_queryable, predicate, _query),
    do: raise(PredicateError, message: "Invalid Predicate", predicate: predicate)

  # Convenience wrapper of comparator against association in "any".
  defp convert_comparator(op, {:assoc, field, path}, sub_predicate, queryable, meta),
    do:
      convert_any(
        {:assoc, field},
        %{"op" => op, "path" => path, "arg" => sub_predicate},
        queryable,
        meta
      )

  # Handle Comparators
  defp convert_comparator("eq", target, value, _queryable, _meta),
    do: convert_eq(target, value)

  defp convert_comparator("not_eq", target, value, _queryable, _meta),
    do: convert_not_eq(target, value)

  defp convert_comparator("gt", target, value, _queryable, _meta),
    do: convert_gt(target, value)

  defp convert_comparator("ge", target, value, _queryable, _meta),
    do: convert_ge(target, value)

  defp convert_comparator("lt", target, value, _queryable, _meta),
    do: convert_lt(target, value)

  defp convert_comparator("le", target, value, _queryable, _meta),
    do: convert_le(target, value)

  defp convert_comparator("contains", target, value, _queryable, _meta),
    do: convert_contains(target, value)

  defp convert_comparator("like", target, value, _queryable, _meta),
    do: convert_like(target, value)

  defp convert_comparator("ilike", target, value, _queryable, _meta),
    do: convert_ilike(target, value)

  defp convert_comparator("starts_with", target, value, _queryable, _meta),
    do: convert_starts_with(target, value)

  defp convert_comparator("ends_with", target, value, _queryable, _meta),
    do: convert_ends_with(target, value)

  defp convert_comparator("in", target, value, _queryable, _meta),
    do: convert_in(target, value)

  defp convert_comparator("not_in", target, value, _queryable, _meta),
    do: convert_not_in(target, value)

  # Db converters are separated to be reused internally
  defp convert_eq({:single, field}, nil),
    do: dynamic([q], is_nil(field(q, ^field)))

  defp convert_eq({:virtual, field, :map, json_path}, nil) do
    dynamic(is_nil(^maybe_use_path(field, json_path)))
  end

  defp convert_eq({:json, field, path}, nil),
    do:
      dynamic(
        [q],
        is_nil(fragment("?#>>?", field(q, ^field), ^path))
      )

  defp convert_eq({:json, field, path}, value) when is_boolean(value) or is_number(value),
    do:
      dynamic(
        [q],
        fragment("?#>?", field(q, ^field), ^path) == ^value
      )

  defp convert_eq({:single, field}, value) do
    dynamic([q], field(q, ^field) == ^value)
  end

  defp convert_eq({:virtual, field, type, json_path}, value) do
    dynamic(^maybe_use_path(field, json_path) == ^maybe_cast(value, type))
  end

  defp convert_eq({:json, field, path}, value),
    do:
      dynamic(
        [q],
        fragment("?#>>?", field(q, ^field), ^path) == ^value
      )

  defp convert_not_eq({:single, field}, nil),
    do: dynamic([q], not is_nil(field(q, ^field)))

  defp convert_not_eq({:virtual, field, _, json_path}, nil),
    do: dynamic(not is_nil(^maybe_use_path(field, json_path)))

  defp convert_not_eq({:json, field, path}, nil),
    do: dynamic([q], not is_nil(fragment("?#>>?", field(q, ^field), ^path)))

  defp convert_not_eq({:json, field, path}, value) when is_boolean(value) or is_number(value),
    do:
      dynamic(
        [q],
        fragment("?#>?", field(q, ^field), ^path) != ^value or
          is_nil(fragment("?#>>?", field(q, ^field), ^path))
      )

  defp convert_not_eq({:json, field, path}, value),
    do:
      dynamic(
        [q],
        fragment("?#>>?", field(q, ^field), ^path) != ^value or
          is_nil(fragment("?#>>?", field(q, ^field), ^path))
      )

  defp convert_not_eq({:single, field}, value),
    do: dynamic([q], field(q, ^field) != ^value or is_nil(field(q, ^field)))

  defp convert_not_eq({:virtual, field, type, json_path}, value),
    do:
      dynamic(
        ^maybe_use_path(field, json_path) != ^maybe_cast(value, type) or
          is_nil(^maybe_use_path(field, json_path))
      )

  defp convert_gt({:single, field}, value), do: dynamic([q], field(q, ^field) > ^value)

  defp convert_gt({:virtual, field, type, json_path}, value),
    do: dynamic(^maybe_use_path(field, json_path) > ^maybe_cast(value, type))

  defp convert_gt({:json, field, path}, value),
    do: dynamic([q], fragment("?#>? > ?", field(q, ^field), ^path, ^value))

  defp convert_ge({:single, field}, value),
    do: dynamic([q], field(q, ^field) >= ^value)

  defp convert_ge({:virtual, field, type, json_path}, value),
    do: dynamic(^maybe_use_path(field, json_path) >= ^maybe_cast(value, type))

  defp convert_ge({:json, field, path}, value),
    do: dynamic([q], fragment("?#>? >= ?", field(q, ^field), ^path, ^value))

  defp convert_lt({:single, field}, value), do: dynamic([q], field(q, ^field) < ^value)

  defp convert_lt({:virtual, field, type, json_path}, value),
    do: dynamic(^maybe_use_path(field, json_path) < ^maybe_cast(value, type))

  defp convert_lt({:json, field, path}, value),
    do: dynamic([q], fragment("?#>? < ?", field(q, ^field), ^path, ^value))

  defp convert_le({:single, field}, value),
    do: dynamic([q], field(q, ^field) <= ^value)

  defp convert_le({:virtual, field, type, json_path}, value),
    do: dynamic(^maybe_use_path(field, json_path) <= ^maybe_cast(value, type))

  defp convert_le({:json, field, path}, value),
    do: dynamic([q], fragment("?#>? <= ?", field(q, ^field), ^path, ^value))

  defp convert_like({:single, field}, value),
    do: dynamic([q], like(field(q, ^field), ^"%#{search_to_like_pattern(value)}%"))

  defp convert_like({:virtual, field, _type, _}, value),
    do: dynamic(like(type(^field, :string), ^"%#{search_to_like_pattern(value)}%"))

  defp convert_like({:json, field, path}, value),
    do:
      dynamic(
        [q],
        like(fragment("?#>>?", field(q, ^field), ^path), ^"%#{search_to_like_pattern(value)}%")
      )

  defp convert_ilike({:single, field}, value),
    do: dynamic([q], ilike(field(q, ^field), ^"%#{search_to_like_pattern(value)}%"))

  defp convert_ilike({:virtual, field, _type, _}, value),
    do: dynamic(ilike(type(^field, :string), ^"%#{search_to_like_pattern(value)}%"))

  defp convert_ilike({:json, field, path}, value),
    do:
      dynamic(
        [q],
        ilike(fragment("?#>>?", field(q, ^field), ^path), ^"%#{search_to_like_pattern(value)}%")
      )

  defp convert_contains({:json, field, path}, value),
    # jsonb containment operator, see https://www.postgresql.org/docs/17/datatype-json.html#JSON-CONTAINMENT
    do: dynamic([q], fragment("?#>? @> ?", field(q, ^field), ^path, ^value))

  defp convert_contains(type, value), do: convert_like(type, value)

  defp convert_starts_with({:single, field}, value),
    do: dynamic([q], like(field(q, ^field), ^"#{search_to_like_pattern(value)}%"))

  defp convert_starts_with({:virtual, field, _type, json_path}, value),
    do:
      dynamic(
        like(
          type(^maybe_use_path(field, json_path), :string),
          ^"#{search_to_like_pattern(value)}%"
        )
      )

  defp convert_starts_with({:json, field, path}, value),
    do:
      dynamic(
        [q],
        like(fragment("?#>>?", field(q, ^field), ^path), ^"#{search_to_like_pattern(value)}%")
      )

  defp convert_ends_with({:single, field}, value),
    do: dynamic([q], like(field(q, ^field), ^"%#{search_to_like_pattern(value)}"))

  defp convert_ends_with({:virtual, field, _type, json_path}, value),
    do:
      dynamic(
        like(
          type(^maybe_use_path(field, json_path), :string),
          ^"%#{search_to_like_pattern(value)}%"
        )
      )

  defp convert_ends_with({:json, field, path}, value),
    do:
      dynamic(
        [q],
        like(fragment("?#>>?", field(q, ^field), ^path), ^"%#{search_to_like_pattern(value)}")
      )

  defp convert_in(field, value) when not is_list(value), do: convert_in(field, List.wrap(value))

  defp convert_in({:single, field}, value) do
    # `nil` values will never match with `IN` operator, so we need to handle them separately.
    {values, nil_values} = Enum.split_with(value, &(!is_nil(&1)))

    # Inline field/2 to propagate type info to "not in" operator (important for UUIDs)
    query = dynamic([q], field(q, ^field) in ^values)

    if nil_values == [],
      do: query,
      else: dynamic([q], ^query or is_nil(field(q, ^field)))
  end

  defp convert_in({:virtual, field, type, json_path}, value) do
    # `nil` values will never match with `IN` operator, so we need to handle them separately.
    {values, nil_values} = Enum.split_with(value, &(!is_nil(&1)))

    query = dynamic(^maybe_use_path(field, json_path) in ^maybe_cast_array(values, type))

    if nil_values == [],
      do: query,
      else: dynamic(^query or is_nil(^field))
  end

  defp convert_in({:json, field, path}, value) do
    # `nil` values will never match with `IN` operator, so we need to handle them separately.
    {values, nil_values} = Enum.split_with(value, &(!is_nil(&1)))

    db_field = dynamic([q], fragment("?#>?", field(q, ^field), ^path))
    query = dynamic(^db_field in ^values)

    if nil_values == [],
      do: query,
      else: dynamic(^query or is_nullish(^db_field))
  end

  defp convert_not_in(field, value) when not is_list(value),
    do: convert_not_in(field, List.wrap(value))

  defp convert_not_in({:single, field}, value) do
    # `nil` values will never match with `NOT IN` operator, so we need to handle them separately.
    {values, nil_values} = Enum.split_with(value, &(!is_nil(&1)))

    db_field = dynamic([q], field(q, ^field))
    # Inline field/2 to propagate type info to "not in" operator (important for UUIDs)
    query = dynamic([q], field(q, ^field) not in ^values)

    if nil_values == [],
      do: dynamic(^query or is_nil(^db_field)),
      else: dynamic(^query and not is_nil(^db_field))
  end

  defp convert_not_in({:virtual, field, type, json_path}, value) do
    # `nil` values will never match with `NOT IN` operator, so we need to handle them separately.
    {values, nil_values} = Enum.split_with(value, &(!is_nil(&1)))

    query = dynamic(^maybe_use_path(field, json_path) not in ^maybe_cast_array(values, type))

    if nil_values == [],
      do: dynamic(^query or is_nil(^maybe_use_path(field, json_path))),
      else: dynamic(^query and not is_nil(^maybe_use_path(field, json_path)))
  end

  defp convert_not_in({:json, field, path}, value) do
    # `nil` values will never match with `NOT IN` operator, so we need to handle them separately.
    {values, nil_values} = Enum.split_with(value, &(!is_nil(&1)))

    db_field = dynamic([q], fragment("?#>?", field(q, ^field), ^path))
    query = dynamic(^db_field not in ^values)

    if nil_values == [],
      do: dynamic(^query or is_nullish(^db_field)),
      else: dynamic(^query and not is_nullish(^db_field))
  end

  defp convert_any({:assoc, field}, sub_predicate, queryable, meta) do
    schema = get_schema(queryable)

    sub_association = get_association_field(schema, field)

    if is_nil(sub_association) do
      raise PredicateError,
        message: "Field '#{field}' in schema #{inspect(schema)} is not an association"
    else
      parent_table_name = get_table_name(sub_association.owner)

      sub_schema = get_schema(sub_association)

      # define the subquery to execute the given predicates against the defined association
      subquery =
        from(s in sub_schema,
          select: 1,
          where:
            field(s, ^sub_association.related_key) ==
              field(parent_as(^parent_table_name), ^sub_association.owner_key)
        )
        |> build_sub_query(sub_predicate, meta)

      dynamic(exists(subquery))
    end
  end

  defp convert_any({:single, field}, sub_predicate, queryable, meta) do
    parent_table = get_table_name(queryable)

    subquery =
      from(
        s in fragment("select unnest(?) as __element__", field(parent_as(^parent_table), ^field)),
        select: s.__element__
      )

    subquery =
      subquery
      |> where(^convert_query(subquery, Map.put(sub_predicate, "path", :__element__), meta))

    dynamic(exists(subquery))
  end

  defp convert_any({:virtual, field, {:array, :map}, json_path}, sub_predicate, queryable, meta) do
    subquery =
      subquery(
        from(t in field,
          select: %{
            __element__: fragment("jsonb_array_elements(?)", t.__value__)
          }
        )
      )

    dbg()

    subquery =
      subquery
      |> where(
        ^convert_query(subquery, sub_predicate, Map.put(meta, :__nested_virtual_json__, true))
      )

    dynamic(exists(subquery))
  end

  defp maybe_cast(value, :utc_datetime), do: dynamic(type(^value, :utc_datetime))
  defp maybe_cast(value, :utc_datetime_usec), do: dynamic(type(^value, :utc_datetime_usec))
  defp maybe_cast(value, _), do: value

  defp maybe_cast_array(value, :utc_datetime), do: dynamic(type(^value, {:array, :utc_datetime}))

  defp maybe_cast_array(value, :utc_datetime_usec),
    do: dynamic(type(^value, {:array, :utc_datetime_usec}))

  defp maybe_cast_array(value, _), do: value

  defp build_sub_query(queryable, sub_predicate, %{"client_id" => client_id} = query)
       when is_binary(client_id) do
    schema = get_schema(queryable)
    # Check if the associated schema has a method to get the client query key
    if Kernel.function_exported?(schema, :client_query_key, 0) do
      # With a client query key we add a filter for the client id from the query to secure the relevant values
      # This is relevant for schemas that can have different content for different clients (leasing)
      case schema.client_query_key() do
        client_key when is_atom(client_key) ->
          # add the client id filter if a client query key is defined
          build_query(queryable, sub_predicate, query)
          |> where([q], field(q, ^client_key) == ^client_id)

        _ ->
          build_query(queryable, sub_predicate, query)
      end
    else
      build_query(queryable, sub_predicate, query)
    end
  end

  defp build_sub_query(queryable, sub_predicate, query),
    do: build_query(queryable, sub_predicate, query)

  # Used by convert_any({:single, ...) to anchor the sub-predicate on the special __element__ field
  defp process_path(_queryable, :__element__, _meta), do: {:single, :__element__}

  defp process_path(_queryable, "", _meta),
    do: raise(PredicateError, message: "Empty path is not allowed")

  defp process_path(queryable, path, meta) when is_binary(path),
    do: process_path(queryable, String.split(path, ".", trim: true), meta)

  defp process_path(queryable, path, meta) when is_atom(path),
    do: process_path(queryable, [path], meta)

  # Used by convert_any({:virtual, ...) for an array of maps to anchor the sub-predicate on the special __element__
  # field
  defp process_path(%Ecto.SubQuery{}, json_path, _meta), do: {:json, :__element__, json_path}

  # check for existing fields and throw an error if the field does not exist
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp process_path(queryable, [field | json_path], meta) do
    schema = get_schema(queryable)
    fields = get_schema_fields(schema)
    virtual_fields = get_schema_virtual_fields(schema)

    associations = get_schema_associations(schema)
    atom_field = to_atom_field(field)

    if Enum.member?(fields ++ associations ++ virtual_fields, atom_field) do
      cond do
        get_field_type(schema, atom_field) == :map and json_path != [] ->
          # it is a regular field of type map -> json and we have a path to use a value within the json
          {:json, atom_field, json_path}

        Enum.member?(fields, atom_field) ->
          # simple field of a non associated type
          {:single, atom_field}

        Enum.member?(virtual_fields, atom_field) ->
          # computed/virtual field (might not be supported by the schema)
          virtual_field =
            try do
              safe_call({schema, :get_virtual_field}, [atom_field, meta], 1)
            rescue
              [FunctionClauseError, UndefinedFunctionError] ->
                # credo:disable-for-next-line Credo.Check.Warning.RaiseInsideRescue
                raise PredicateError,
                  message:
                    "Virtual field '#{field}' not handled via &get_virtual_field/1 or &get_virtual_field/2 in schema #{inspect(schema)}"
            end

          type = get_virtual_field_type(schema, atom_field)

          if json_path != [] and type == {:array, :map},
            do:
              raise(PredicateError,
                message:
                  "Can't use JSON path on virtual field '#{field}' of type {:array, :map}, use explicit 'any' instead (remaining path: #{inspect(json_path)})"
              )

          {:virtual, virtual_field, type, json_path}

        Enum.member?(associations, atom_field) ->
          # it is an association field and we probably have a sub path into the associations
          {:assoc, atom_field, json_path}

        true ->
          raise PredicateError,
            message: "Field '#{field}' in schema #{inspect(schema)} is not allowed"
      end
    else
      raise PredicateError,
        message: "Field '#{field}' does not exist in schema #{inspect(schema)}"
    end
  end

  defp to_atom_field(field) when is_atom(field), do: field

  defp to_atom_field(field) when is_binary(field) do
    String.to_existing_atom(field)
  rescue
    ArgumentError ->
      raise PredicateError, message: "Field '#{field}' does not exist"
  end

  defp maybe_use_path(field, []), do: field

  defp maybe_use_path(field, json_path),
    do: dynamic(fragment("?#>>?", ^field, ^json_path))
end
