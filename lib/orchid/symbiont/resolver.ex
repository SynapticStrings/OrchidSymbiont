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
        {ttl, worker_args} = Keyword.pop(args, :ttl)

        via_name = {:via, Registry, {Orchid.Symbiont.Registry, name}}

        child_spec =
          if ttl do
            %{
              id: name,
              start:
                {Orchid.Symbiont.TTLWrapper, :start_link,
                 [
                   [
                     name: via_name,
                     worker_mod: mod,
                     worker_args: worker_args,
                     ttl: ttl
                   ]
                 ]},
              restart: :temporary
            }
          else
            final_args = Keyword.put(worker_args, :name, via_name)

            %{
              id: name,
              start: {mod, :start_link, [final_args]},
              restart: :temporary
            }
          end

        case DynamicSupervisor.start_child(Orchid.Symbiont.DynamicSupervisor, child_spec) do
          {:ok, pid} -> {:ok, %Handler{name: name, ref: pid}}
          {:ok, pid, _info} -> {:ok, %Handler{name: name, ref: pid}}
          {:error, {:already_started, pid}} -> {:ok, %Handler{name: name, ref: pid}}
          error -> error
        end
    end
  end
end
