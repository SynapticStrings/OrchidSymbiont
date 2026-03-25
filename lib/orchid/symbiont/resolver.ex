defmodule OrchidSymbiont.Resolver do
  alias OrchidSymbiont.{Catalog, Handler, Naming}

  def resolve(session_id \\ nil, name, opts \\ []) do
    strict? = Keyword.get(opts, :strict_mode, false)

    session_catalog_name = if session_id, do: Naming.catalog(session_id), else: nil

    result =
      if session_catalog_name do
        Catalog.lookup(session_catalog_name, name)
      else
        :not_found
      end

    case result do
      {:ok, spec} ->
        start_symbiont(session_id, name, spec)

      :not_found ->
        cond do
          strict? ->
            {:error,
             {:strict_mode_violation,
              "Service #{inspect(name)} not found in session #{session_id}"}}

          true ->
            case Catalog.lookup(Naming.catalog(nil), name) do
              {:ok, spec} -> start_symbiont(session_id, name, spec)
              :not_found -> {:error, {:unknown_symbiont, name}}
            end
        end
    end
  end

  defp start_symbiont(session_id, name, {mod, args}) do
    registry = Naming.get_registry()
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
