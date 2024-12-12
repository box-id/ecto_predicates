defmodule Predicates.Repo do
  use Ecto.Repo,
    otp_app: :predicate_to_ecto_converter,
    adapter: Ecto.Adapters.Postgres

  use OK.Pipe

  @doc """
  Dynamically loads the repository url from the
  DATABASE_URL environment variable.
  """
  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL"))}
  end

  @doc """
  Register a handler function to be executed after the multi has been sucessfully run (requires the multi to be executed
  using `transaction_with_postprocessing/1` instead of `transaction/1,2`!)

  Handler functions take the multi's result and can act on that data and transform it.
  """
  @spec register_handler(multi :: Ecto.Multi.t(), handler :: (map -> map)) :: Ecto.Multi.t()
  def register_handler(multi, handler) do
    Map.update(multi, :_handlers, [handler], &[handler | &1])
  end

  @doc """
  Run an Ecto.Multi in a transaction and, if sucessfull, execute all handlers that have been attached to the multi using
  `register_handler/2`. Note that these handlers can modify the multi's result.
  """
  @spec transaction_with_postprocessing(multi :: Ecto.Multi.t()) :: {:error, any} | {:ok, any}
  def transaction_with_postprocessing(multi) do
    multi
    |> transaction()
    |> case do
      {:ok, changes} ->
        {:ok, run_handlers(changes, multi)}

      # Wrap Ecto Multi errors in the result-tuple form.
      {:error, operation, value, changes_so_far} ->
        {:error, {operation, value, changes_so_far}}
    end
  end

  defp run_handlers(changes, multi) do
    handlers = Map.get(multi, :_handlers, [])
    Enum.reduce(handlers, changes, & &1.(&2))
  end

  @doc """
  Execute `fun` in the context of a database transaction, automatically rolling back when an error tuple is returned.

  When `fun` returns `{:ok, value}`, the trasnaction is committed and this function retuens the same result tuple.
  if `fun` returns `{:error, reason}`, the transaction is rolled back and this function returns the same erorr tuple.
  """
  def transaction_ok(fun) do
    transaction(fn ->
      case fun.() do
        {:ok, result} ->
          result

        {:error, reason} ->
          rollback(reason)

        value ->
          raise "Repo.transaction_ok: `fun` did neither return an `{:ok, value}` nor `{:error, reason}` tuple. Did you forget to wrap the value in a result tuple?\n\nInstead received:\n#{inspect(value)}"
      end
    end)
  end

  @doc """
  The same as `transaction_ok/1`, except that `data_in` will be passed to `fun`, which allows for easier use in pipes.
  """
  def transaction_ok(data_in, fun) do
    transaction_ok(fn -> fun.(data_in) end)
  end

  @doc """
  The same as the regular `Repo.update/2`, but stores the changeset's initial data under `:_before` on the result as per
  our convention.
  """
  def update_with_before(changeset, opts \\ [])

  def update_with_before(%Ecto.Changeset{data: before} = changeset, opts) do
    update(changeset, opts)
    ~> Map.put(:_before, before)
  end
end
