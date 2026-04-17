defmodule MyApp.Calls.CallSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_call_session(call_id, call_sid, agent, contact) do
    spec = {
      MyApp.Calls.CallSession,
      {call_id, call_sid, agent, contact}
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_call_session(call_sid) do
    case MyApp.Calls.CallSession.whereis(call_sid) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end
end
