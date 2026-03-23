defmodule Orchid.Symbiont.Runtime do
  use Supervisor
  alias Orchid.Symbiont.Naming

  def start_link(init_arg) do
    session_id = Keyword.get(init_arg, :session_id)
    Supervisor.start_link(__MODULE__, init_arg, name: Module.concat([Naming.dynamic_supervisor(session_id), Supervisor]))
  end

  @impl true
  def init(init_arg) do
    session_id = Keyword.get(init_arg, :session_id)

    children = [
      {Registry, keys: :unique, name: Naming.registry(session_id)},
      {DynamicSupervisor, name: Naming.dynamic_supervisor(session_id), strategy: :one_for_one},

      {Orchid.Symbiont.Catalog, session_id: session_id, name: Naming.catalog(session_id)},

      {Task.Supervisor, name: Naming.preloader(session_id)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
