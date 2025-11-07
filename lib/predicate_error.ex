defmodule Predicates.PredicateError do
  @moduledoc """
  Exception raised for errors related to predicate processing.

  Contains the offending predicate for easier debugging, so beware of leaking sensitive structural information if
  propagating the error to end-users.

  If Plug is available, it implements the `Plug.Exception` protocol to return a 400 status code.
  """

  defexception [:message, :predicate]

  def message(%{message: message, predicate: predicate}) when not is_nil(predicate) do
    """
    #{message}

    Predicate:
    #{format_predicate(predicate)}
    """
  end

  def message(%{message: message}), do: message

  defp format_predicate(predicate) do
    inspect(predicate, pretty: true, limit: :infinity)
  end

  if Code.ensure_loaded?(Plug) do
    defimpl Plug.Exception do
      def status(_exception), do: 400
      def actions(_exception), do: []
    end
  end
end
