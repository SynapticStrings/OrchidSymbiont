defmodule OrchidSymbiont.Naming do
  @moduledoc "Responsible for mapping logical components (after mapper) to actual process registration names."
  @registry OrchidSymbiont.Registry

  def get_registry, do: @registry

  def catalog(nil), do: OrchidSymbiont.Catalog
  def catalog(session_id), do: via_tuple(session_id, :catalog)

  def dynamic_supervisor(nil), do: OrchidSymbiont.DynamicSupervisor
  def dynamic_supervisor(session_id), do: via_tuple(session_id, :supervisor)

  defp via_tuple(session_id, role) do
    {:via, Registry, {@registry, {session_id, role}}}
  end
end
