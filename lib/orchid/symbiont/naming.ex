defmodule Orchid.Symbiont.Naming do
  @moduledoc "负责将逻辑组件映射到实际的进程注册名"

  def registry(nil), do: Orchid.Symbiont.Registry
  def registry(session_id), do: Module.concat([session_id, Symbiont, Registry])

  def dynamic_supervisor(nil), do: Orchid.Symbiont.DynamicSupervisor
  def dynamic_supervisor(session_id), do: Module.concat([session_id, Symbiont, DynamicSupervisor])

  def catalog(nil), do: Orchid.Symbiont.Catalog
  def catalog(session_id), do: Module.concat([session_id, Symbiont, Catalog])

  def preloader(nil), do: Orchid.Symbiont.Preloader
  def preloader(session_id), do: Module.concat([session_id, Symbiont, Preloader])
end 
