defmodule MyApp.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MyAppWeb.Telemetry,
      MyApp.Repo,
      {DNSCluster, query: Application.get_env(:my_app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MyApp.PubSub},
      {Registry, keys: :unique, name: MyApp.Calls.CallRegistry},
      MyApp.Calls.CallSupervisor,
      MyAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    MyAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
