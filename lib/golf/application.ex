defmodule Golf.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Golf.Repo,
      # Start the Telemetry supervisor
      GolfWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Golf.PubSub},
      # Start the Endpoint (http/https)
      GolfWeb.Endpoint,
      # Start the game registry
      {Registry, name: Golf.GameRegistry, keys: :unique},
      # Start the game supervisor
      {DynamicSupervisor, name: Golf.GameSupervisor, strategy: :one_for_one}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Golf.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GolfWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
