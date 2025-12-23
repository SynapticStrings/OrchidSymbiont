defmodule Orchid.Symbiont.Resolver do
  alias Orchid.Symbiont.{Catalog, Handler}

  def resolve(name) do
    # 1. 检查是否已经存活
    case Registry.lookup(Orchid.Symbiont.Registry, name) do
      [{pid, _val}] ->
        {:ok, %Handler{name: name, ref: pid}}

      [] ->
        # 2. 尝试启动
        start_symbiont(name)
    end
  end

  defp start_symbiont(name) do
    case Catalog.lookup(name) do
      nil ->
        {:error, {:unknown_symbiont, name}}

      {mod, args} ->
        # 3. 构造 Child Spec
        # 关键点：强制加上 name: {:via, ...} 使得进程启动时自动注册进 Registry
        via_name = {:via, Registry, {Orchid.Symbiont.Registry, name}}

        # 假设用户的 start_link 接受 [name: ...] 参数
        # 这里可能需要根据你的实际 GenServer 规范调整
        args = Keyword.put(args, :name, via_name)

        child_spec = %{
          id: name,
          start: {mod, :start_link, [args]},
          restart: :temporary # 等待下一次 resolve 触发
        }

        case DynamicSupervisor.start_child(Orchid.Symbiont.DynamicSupervisor, child_spec) do
          {:ok, pid} -> {:ok, %Handler{name: name, ref: pid}}
          {:ok, pid, _info} -> {:ok, %Handler{name: name, ref: pid}}
          {:error, {:already_started, pid}} -> {:ok, %Handler{name: name, ref: pid}}
          error -> error
        end
    end
  end
end
