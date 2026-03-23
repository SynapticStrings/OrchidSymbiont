defmodule Orchid.Symbiont.Runtime do
  use Supervisor
  alias Orchid.Symbiont.Naming

  def start_link(opts) do
    session_id = Keyword.get(opts, :session_id)
    name = Naming.session_supervisor(session_id)

    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
