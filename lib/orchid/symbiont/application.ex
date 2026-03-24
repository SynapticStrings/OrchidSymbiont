defmodule Orchid.Symbiont.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Orchid.Symbiont.Registry},
      Orchid.Symbiont.Catalog,
      {Orchid.Symbiont.Runtime, session_id: nil},
      # TODO: Add a `strict_mode`
      # If ture, not fallback to global mode.
      {Task.Supervisor, name: Orchid.Symbiont.Preloader},
    ]

    opts = [strategy: :one_for_one, name: Orchid.Symbiont.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
