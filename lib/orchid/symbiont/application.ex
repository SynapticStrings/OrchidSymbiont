defmodule OrchidSymbiont.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: OrchidSymbiont.Registry},
      OrchidSymbiont.Catalog,
      {OrchidSymbiont.Runtime, session_id: nil},
      # TODO: Add a `strict_mode`
      # If ture, not fallback to global mode.
      {Task.Supervisor, name: OrchidSymbiont.Preloader},
    ]

    opts = [strategy: :one_for_one, name: OrchidSymbiont.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
