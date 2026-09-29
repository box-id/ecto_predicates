defmodule Predicates.Test.LTree do
  @moduledoc false
  # Minimal Ecto type for Postgres ltree columns, auto-detected via `type/0`.
  use Ecto.Type

  def type, do: :ltree

  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(_), do: :error

  def load(value) when is_binary(value), do: {:ok, value}
  def load(_), do: :error

  def dump(value) when is_binary(value), do: {:ok, value}
  def dump(_), do: :error
end

defmodule Predicates.Test.ConfiguredLTree do
  @moduledoc false
  # ltree type that isn't auto-detectable and has to be listed in the `:ltree_types` config.
  use Ecto.Type

  def type, do: :string

  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(_), do: :error

  def load(value) when is_binary(value), do: {:ok, value}
  def load(_), do: :error

  def dump(value) when is_binary(value), do: {:ok, value}
  def dump(_), do: :error
end
