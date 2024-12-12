defmodule Predicates.PredicateError do
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
    case Jason.encode(predicate, pretty: true) do
      {:ok, json} -> json
      {:error, _} -> inspect(predicate)
    end
  end

  defimpl Plug.Exception do
    def status(_exception), do: 400
    def actions(_exception), do: []
  end
end
