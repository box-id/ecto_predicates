defmodule Predicates.PredicateConverter do
  @moduledoc """
  This module is capable to convert a predicate map into an ecto query based on the defined schemas.

  Junctor Predicate:
  %{
    op: :and | :or,
    args: Predicate.t()
  }

  Negation Predicate:
  %{
    op: :not,
    arg: Predicate.t()
  }

  Quantor Predicate:
  %{
    op: :all | :any,
    path: binary() | [binary() | atom()],
    arg: Predicate.t()
  }

  Comparator Predicate:
  %{
    op: :eq | :gt | :ge | :lt | :le | :contains | :like | :ilike | :in | :not_in | :starts_with

    path: binary() | [binary() | atom()],
    arg: any()
  }

  Value Predicate:
  %{
    arg: boolean
  }

  The `path` can be:

  - An actual field name on the model schema
  - An association name on the model schema
  - A virtual field *if* the schema module implements either `virtual_field(name)` or `virtual_field(name, query)` that
    returns a `dynamic` query resolving to the virtual field's value.
  """
  import Ecto.Query
  import Predicates.SchemaHelpers

  alias Predicates.PredicateError
  alias Utils

  # create a ecto query from the given predicates
  @spec build_query(queryable :: Ecto.Queryable.t(), predicate :: Map.t(), query :: Map.t()) ::
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

    where(queryable, [q], ^convert_query(queryable, predicate, query))
  end

  # create dynamic ecto queries fragments from the given predicates.
  @spec convert_query(queryable :: Ecto.Queryable.t(), predicate :: Map.t(), query :: Map.t()) ::
          Macro.t()
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
      dynamic([q], ^acc and ^convert_query(queryable, sub_predicate, query))
    end)
  end

  # combine predicates with a "or" operation
  def convert_query(queryable, %{"op" => "or", "args" => sub_predicates}, query) do
    Enum.reduce(sub_predicates, dynamic(false), fn sub_predicate, acc ->
      dynamic([q], ^acc or ^convert_query(queryable, sub_predicate, query))
    end)
  end

  # Negation Predicate
  def convert_query(queryable, %{"op" => "not", "arg" => sub_predicates}, query) do
    dynamic([q], not (^convert_query(queryable, sub_predicates, query)))
  end

  # Quantor Predicate
  def convert_query(queryable, %{"op" => "any", "path" => path, "arg" => sub_predicate}, meta) do
    case process_path(queryable, path, meta) do
      {:assoc, field, _} ->
        convert_any({:assoc, field}, sub_predicate, queryable, meta)

      _ ->
        raise PredicateError,
          message: "Operator 'any' is currently only supported on associations"
    end
  end

  # Comparator Predicates
  def convert_query(queryable, %{"op" => op, "path" => path, "arg" => value} = predicate, meta) do
    convert_comparator(op, process_path(queryable, path, meta), value, queryable, meta)
  rescue
    FunctionClauseError ->
      # credo:disable-for-next-line Credo.Check.Warning.RaiseInsideRescue
      raise PredicateError, message: "Operator #{inspect(op)} not supported", predicate: predicate

    e ->
      reraise e, __STACKTRACE__
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

  defp convert_comparator("in", target, value, _queryable, _meta),
    do: convert_in(target, value)

  defp convert_comparator("not_in", target, value, _queryable, _meta),
    do: convert_not_in(target, value)

  # Db converters are separated to be reused internally
  defp convert_eq({:single, field}, nil),
    do: dynamic([q], is_nil(field(q, ^field)))

  defp convert_eq({:virtual, field, _}, nil),
    do: dynamic([q], is_nil(^field))

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

  defp convert_eq({:virtual, field, type}, value) do
    dynamic(^field == ^maybe_cast(value, type))
  end

  defp convert_eq({:json, field, path}, value),
    do:
      dynamic(
        [q],
        fragment("?#>>?", field(q, ^field), ^path) == ^value
      )

  defp convert_gt({:single, field}, value), do: dynamic([q], field(q, ^field) > ^value)

  defp convert_gt({:virtual, field, type}, value),
    do: dynamic([q], ^field > ^maybe_cast(value, type))

  defp convert_gt({:json, field, path}, value),
    do: dynamic([q], fragment("?#>? > ?", field(q, ^field), ^path, ^value))

  defp convert_ge({:single, field}, value),
    do: dynamic([q], field(q, ^field) >= ^value)

  defp convert_ge({:virtual, field, type}, value),
    do: dynamic([q], ^field >= ^maybe_cast(value, type))

  defp convert_ge({:json, field, path}, value),
    do: dynamic([q], fragment("?#>? >= ?", field(q, ^field), ^path, ^value))

  defp convert_lt({:single, field}, value), do: dynamic([q], field(q, ^field) < ^value)

  defp convert_lt({:virtual, field, type}, value),
    do: dynamic([q], ^field < ^maybe_cast(value, type))

  defp convert_lt({:json, field, path}, value),
    do: dynamic([q], fragment("?#>? < ?", field(q, ^field), ^path, ^value))

  defp convert_le({:single, field}, value),
    do: dynamic([q], field(q, ^field) <= ^value)

  defp convert_le({:virtual, field, type}, value),
    do: dynamic([q], ^field <= ^maybe_cast(value, type))

  defp convert_le({:json, field, path}, value),
    do: dynamic([q], fragment("?#>? <= ?", field(q, ^field), ^path, ^value))

  defp convert_like({:single, field}, value),
    do: dynamic([q], like(field(q, ^field), ^"%#{value}%"))

  defp convert_like({:virtual, field, _type}, value),
    do: dynamic([q], like(type(^field, :string), ^"%#{value}%"))

  defp convert_like({:json, field, path}, value),
    do: dynamic([q], like(fragment("?#>>?", field(q, ^field), ^path), ^"%#{value}%"))

  defp convert_ilike({:single, field}, value),
    do: dynamic([q], ilike(field(q, ^field), ^"%#{value}%"))

  defp convert_ilike({:virtual, field, _type}, value),
    do: dynamic(ilike(type(^field, :string), ^"%#{value}%"))

  defp convert_ilike({:json, field, path}, value),
    do: dynamic([q], ilike(fragment("?#>>?", field(q, ^field), ^path), ^"%#{value}%"))

  defp convert_contains({:json, field, path}, value),
    do: dynamic([q], fragment("?#>? @> ?", field(q, ^field), ^path, ^value))

  defp convert_contains(type, value), do: convert_like(type, value)

  defp convert_starts_with({:single, field}, value),
    do: dynamic([q], like(field(q, ^field), ^"#{value}%"))

  defp convert_starts_with({:virtual, field, _type}, value),
    do: dynamic([q], like(type(^field, :string), ^"#{value}%"))

  defp convert_starts_with({:json, field, path}, value),
    do: dynamic([q], like(fragment("?#>>?", field(q, ^field), ^path), ^"#{value}%"))

  defp convert_in({:single, field}, value),
    do: dynamic([q], field(q, ^field) in ^value)

  defp convert_in({:virtual, field, type}, value),
    do: dynamic([q], ^field in ^maybe_cast_array(value, type))

  defp convert_in({:json, field, path}, value),
    do: dynamic([q], fragment("?#>? = ANY(?)", field(q, ^field), ^path, ^value))

  defp convert_not_in({:single, field}, value), do: dynamic([q], field(q, ^field) not in ^value)

  defp convert_not_in({:virtual, field, type}, value),
    do: dynamic([q], ^field not in ^maybe_cast_array(value, type))

  defp convert_not_in({:json, field, path}, value),
    do: dynamic([q], not fragment("?#>? = ANY(?)", field(q, ^field), ^path, ^value))

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

      dynamic(
        [q],
        exists(subquery)
      )
    end
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

  # check for existing fields and throw an error if the field does not exist
  defp process_path(queryable, path, meta) when is_binary(path),
    do: process_path(queryable, String.split(path, "."), meta)

  defp process_path(queryable, path, meta) when is_atom(path),
    do: process_path(queryable, [path], meta)

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp process_path(queryable, [field | json_path], meta) do
    schema = get_schema(queryable)
    fields = get_schema_fields(schema)
    virtual_fields = get_schema_virtual_fields(schema)

    associations = get_schema_associations(schema)
    atom_field = to_atom_field(field)

    if Enum.member?(fields ++ associations ++ virtual_fields, atom_field) do
      cond do
        get_field_type(schema, atom_field) == :map and length(json_path) ->
          # it is a regular field of type map -> json and we have a path to use a value within the json
          {:json, atom_field, json_path}

        Enum.member?(fields, atom_field) ->
          # simple field of a non associated type
          {:single, atom_field}

        Enum.member?(virtual_fields, atom_field) ->
          # computed/virtual field (might not be supported by the schema)
          virtual_field =
            try do
              Utils.safe_call({schema, :get_virtual_field}, [atom_field, meta], 1)
            rescue
              [FunctionClauseError, UndefinedFunctionError] ->
                # credo:disable-for-next-line Credo.Check.Warning.RaiseInsideRescue
                raise PredicateError,
                  message:
                    "Virtual field '#{field}' not handled via &get_virtual_field/1 or &get_virtual_field/2 in schema #{inspect(schema)}"
            end

          type = get_virtual_field_type(schema, atom_field)
          {:virtual, virtual_field, type}

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
  # to_existing_atom not possible e.g. for "asset_labels"
  defp to_atom_field(field) when is_binary(field), do: String.to_atom(field)
end
