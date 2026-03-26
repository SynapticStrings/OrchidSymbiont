defmodule OrchidSymbiont.Naming do
  @moduledoc "Responsible for mapping logical components (after mapper) to actual process registration names."
  @registry OrchidSymbiont.Registry

  def get_registry, do: @registry

  def catalog(nil), do: OrchidSymbiont.Catalog
  def catalog(scope_id), do: via_tuple(scope_id, :catalog)

  def dynamic_supervisor(nil), do: OrchidSymbiont.DynamicSupervisor
  def dynamic_supervisor(scope_id), do: via_tuple(scope_id, :supervisor)

  defp via_tuple(scope_id, role) do
    {:via, Registry, {@registry, {scope_id, role}}}
  end
end
