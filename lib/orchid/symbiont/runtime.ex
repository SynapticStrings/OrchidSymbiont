defmodule OrchidSymbiont.Runtime do
  use Supervisor

  def start_link(init_arg) do
    case Keyword.get(init_arg, :scope_id) do
      nil -> Supervisor.start_link(__MODULE__, :global, name: __MODULE__)
      scope_id -> Supervisor.start_link(__MODULE__, {:scope, scope_id})
    end
  end

  @impl true
  def init(:global) do
    children = [
      {Registry, keys: :unique, name: OrchidSymbiont.Naming.get_registry()},
      {OrchidSymbiont.Catalog, []},
      {DynamicSupervisor,
       name: OrchidSymbiont.Naming.dynamic_supervisor(nil), strategy: :one_for_one},
      {Task.Supervisor, name: OrchidSymbiont.Preloader}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @impl true
  def init({:scope, scope_id}) do
    children = [
      # 启动 scope Catalog
      {OrchidSymbiont.Catalog, [scope_id: scope_id]},
      {DynamicSupervisor,
       name: OrchidSymbiont.Naming.dynamic_supervisor(scope_id), strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
