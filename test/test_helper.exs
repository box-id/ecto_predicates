ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Predicates.Repo, :manual)

defmodule TestHelper do
  @moduledoc false
  def to_binary_keys(data) when is_map(data) do
    Map.new(data, &reduce_keys_to_binary/1)
  end

  def to_binary_keys(val), do: val

  defp reduce_keys_to_binary({key, val}) when is_map(val),
    do: {atom_to_binary(key), to_binary_keys(val)}

  defp reduce_keys_to_binary({key, val}) when is_list(val),
    do: {atom_to_binary(key), Enum.map(val, &to_binary_keys(&1))}

  defp reduce_keys_to_binary({key, val}) when is_number(val) or is_boolean(val),
    do: {atom_to_binary(key), val}

  defp reduce_keys_to_binary({key, val}), do: {atom_to_binary(key), atom_to_binary(val)}
  defp reduce_keys_to_binary(val), do: atom_to_binary(val)

  defp atom_to_binary(nil), do: nil
  defp atom_to_binary(inp) when is_atom(inp), do: Atom.to_string(inp)
  defp atom_to_binary(inp), do: inp

  def rand_string(
        length,
        charset \\ "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      ) do
    for _ <- 1..length,
        do: Enum.random(String.codepoints(charset)),
        into: ""
  end

  def invert_case(input) when is_binary(input) do
    input
    |> String.to_charlist()
    |> Enum.map(fn
      char when char in ?a..?z -> char - 32
      char when char in ?A..?Z -> char + 32
      char -> char
    end)
    |> List.to_string()
  end

  def rand_boolean, do: :rand.uniform_real() < 0.5

  def to_atom_keys(input) do
    Map.new(input, fn
      {key, value} when is_binary(key) ->
        {String.to_existing_atom(key), value}

      {key, value} ->
        {key, value}
    end)
  end
end
