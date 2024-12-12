defmodule Predicates.Application do
  use Application
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    # Define workers and child supervisors to be supervised
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Predicates.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  # List all child processes to be supervised.
  defp children() do
    [
      # Start the Ecto repository
      Predicates.Repo
    ]
  end
end
