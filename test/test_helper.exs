ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Predicates.Repo, :manual)

defmodule TestHelper do
  @moduledoc false

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
end
