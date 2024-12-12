defmodule Predicates.SchemaHelpers do
  @moduledoc """
  Helper functions for extracting information from a schemas
  """

  alias Predicates.PredicateError

  def get_schema(%Ecto.Query{} = queryable) do
    {_table_name, schema} = queryable.from.source
    schema
  end

  def get_schema(%Ecto.Association.Has{related: schema}), do: schema
  def get_schema(%Ecto.Association.BelongsTo{related: schema}), do: schema

  def get_schema(%Ecto.Association.HasThrough{field: field, owner: owner}),
    do:
      raise(PredicateError,
        message:
          "HasThrough association '#{Module.split(owner) |> List.last()}.#{field}' is not supported"
      )

  def get_schema(%Ecto.Association.ManyToMany{field: field, owner: owner}),
    do:
      raise(PredicateError,
        message:
          "ManyToMany association '#{Module.split(owner) |> List.last()}.#{field}' is not supported"
      )

  def get_schema(input) do
    if input.__schema__(:source) do
      input
    else
      raise "Could not get schema from #{inspect(input)}"
    end
  end

  def get_table_name(%Ecto.Query{} = queryable),
    do: get_schema(queryable) |> get_table_name()

  def get_table_name(schema), do: String.to_atom(schema.__schema__(:source))

  def get_schema_fields(schema),
    do: get_schema(schema).__schema__(:fields)

  def get_schema_virtual_fields(schema),
    do: get_schema(schema).__schema__(:virtual_fields)

  def get_field_type(schema, field), do: schema.__schema__(:type, field)

  def get_virtual_field_type(schema, field), do: schema.__schema__(:virtual_type, field)

  def get_primary_key(schema), do: schema.__schema__(:primary_key)

  def get_schema_associations(schema), do: schema.__schema__(:associations)

  def get_association_field(schema, field) do
    schema.__schema__(:association, field)
  end

  def get_schema_from_association(schema, field) do
    schema
    |> get_association_field(field)
    |> get_schema()
  end
end
