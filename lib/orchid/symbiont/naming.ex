defmodule Orchid.Symbiont.Naming do
  @moduledoc "负责将逻辑组件映射到实际的进程注册名"
  @registry Orchid.Symbiont.Registry

  def get_registry, do: @registry

  def dynamic_supervisor(nil), do: Orchid.Symbiont.DynamicSupervisor
  def dynamic_supervisor(session_id), do: {:via, Registry, {@registry, {session_id, :__supervisor__}}}

  def session_supervisor(session_id) when is_binary(session_id) or is_nil(session_id) do
    {:via, Registry, {@registry, {session_id, :__supervisor__}}}
  end

  def worker(session_id, logical_name) do
    {:via, Registry, {@registry, {session_id, logical_name}}}
  end
end
