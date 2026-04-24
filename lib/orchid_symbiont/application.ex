defmodule OrchidSymbiont.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [OrchidSymbiont.Runtime]

    opts = [strategy: :one_for_one, name: OrchidSymbiont.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
