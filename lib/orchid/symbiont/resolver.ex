defmodule OrchidSymbiont.Resolver do
  alias OrchidSymbiont.{Catalog, Handler, Naming}

  def resolve(session_id \\ nil, name) do
    case Registry.lookup(Naming.get_registry(), {session_id, name}) do
      [{pid, _val}] ->
        {:ok, %Handler{name: name, ref: pid}}

      [] ->
        start_symbiont(session_id, name, Naming.get_registry())
    end
  end

  defp start_symbiont(session_id, name, registry) do
    case Catalog.lookup(session_id, name) do
      nil ->
        {:error, {:unknown_symbiont, name}}

      {mod, args} ->
        {ttl, worker_args} = Keyword.pop(args, :ttl)

        via_name = {:via, Registry, {registry, {session_id, name}}}

        child_spec =
          if ttl do
            %{
              id: name,
              start:
                {OrchidSymbiont.TTLWrapper, :start_link,
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

        dyn_sup = Naming.dynamic_supervisor(session_id)
        case DynamicSupervisor.start_child(dyn_sup, child_spec) do
          {:ok, pid} -> {:ok, %Handler{name: name, ref: pid}}
          {:ok, pid, _info} -> {:ok, %Handler{name: name, ref: pid}}
          {:error, {:already_started, pid}} -> {:ok, %Handler{name: name, ref: pid}}
          error -> error
        end
    end
  end
end
