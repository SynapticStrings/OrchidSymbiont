defmodule OrchidSymbiont.Runtime do
  use Supervisor

  def start_link(session_id: session_id) do
    Supervisor.start_link(__MODULE__, {:session, session_id})
  end

  def start_link(_init_arg) do
    Supervisor.start_link(__MODULE__, :global, name: __MODULE__)
  end

  @impl true
  def init(:global) do
    children = [
      {Registry, keys: :unique, name: OrchidSymbiont.Naming.get_registry()},
      {OrchidSymbiont.Catalog, []},
      {DynamicSupervisor, name: OrchidSymbiont.Naming.dynamic_supervisor(nil), strategy: :one_for_one},
      {Task.Supervisor, name: OrchidSymbiont.Preloader}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end

  @impl true
  def init({:session, session_id}) do
    children = [
      {OrchidSymbiont.Catalog, [session_id: session_id]}, # 启动 Session Catalog
      {DynamicSupervisor, name: OrchidSymbiont.Naming.dynamic_supervisor(session_id), strategy: :one_for_one}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
