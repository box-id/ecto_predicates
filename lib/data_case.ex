defmodule Predicates.DataCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Predicates.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import TestHelper, only: [rand_string: 1, rand_string: 2, rand_boolean: 0, invert_case: 1]

      defp disable_logger(_) do
        Logger.configure(level: :warning)
      end

      # NOTE: Also remove the `backend: []` from config/text.exs to see log output.
      defp enable_logger(_) do
        Logger.configure(level: :debug)
      end
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Predicates.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Predicates.Repo, {:shared, self()})
    end

    :ok
  end

  @doc """
  A helper that transform changeset errors to a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
