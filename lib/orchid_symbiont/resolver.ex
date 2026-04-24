defmodule OrchidSymbiont.Resolver do
  @moduledoc """
  Resolves symbiont names to running process handlers.

  This module handles the on-demand starting of GenServer workers
  based on blueprints registered in the Catalog. It manages the lifecycle
  including TTL-based auto-shutdown and scope isolation.

  ## Resolution Order

  1. Check if a process is already running (via Registry)
  2. Look up the blueprint in the scoped catalog (if scope_id provided)
  3. Fall back to global catalog (unless strict_mode is enabled)
  4. Start the worker via DynamicSupervisor

  ## Strict Mode

  When `strict_mode: true` is passed, the resolver will NOT fall back
  to the global catalog if the blueprint isn't found in the scoped catalog.
  This is useful for multi-tenant applications requiring strong isolation.
  """
  alias OrchidSymbiont.{Catalog, Handler, Naming}

  @doc """
  Resolves a symbiont name to a handler.

  If the worker is already running, returns the existing handler.
  Otherwise, looks up the blueprint and starts the worker on-demand.

  ## Options

    * `:strict_mode` - When `true`, disables catalog fallback to global.
      Returns error if blueprint not found in scoped catalog.

  """
  @spec resolve(binary() | nil, term(), keyword()) :: {:ok, Handler.t()} | {:error, term()}
  def resolve(scope_id \\ nil, name, opts \\ []) do
    strict? = Keyword.get(opts, :strict_mode, false)

    scope_catalog_name = if scope_id, do: Naming.catalog(scope_id), else: nil

    result =
      if scope_catalog_name do
        Catalog.lookup(scope_catalog_name, name)
      else
        :not_found
      end

    case result do
      {:ok, spec} ->
        start_symbiont(scope_id, name, spec)

      :not_found ->
        cond do
          strict? ->
            {:error,
             {:strict_mode_violation, "Service #{inspect(name)} not found in scope #{scope_id}"}}

          true ->
            case Catalog.lookup(Naming.catalog(nil), name) do
              {:ok, spec} -> start_symbiont(scope_id, name, spec)
              :not_found -> {:error, {:unknown_symbiont, name}}
            end
        end
    end
  end

  defp start_symbiont(scope_id, name, {mod, args}) do
    registry = Naming.get_registry()
    {ttl, worker_args} = Keyword.pop(args, :ttl)

    via_name = {:via, Registry, {registry, {scope_id, name}}}

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

    dyn_sup = Naming.dynamic_supervisor(scope_id)

    case DynamicSupervisor.start_child(dyn_sup, child_spec) do
      {:ok, pid} -> {:ok, %Handler{name: name, ref: pid}}
      {:ok, pid, _info} -> {:ok, %Handler{name: name, ref: pid}}
      {:error, {:already_started, pid}} -> {:ok, %Handler{name: name, ref: pid}}
      error -> error
    end
  end

  @doc """
  Returns true if the given reference points to a live process.
  """
  @spec alive?(Handler.t()) :: boolean()
  def alive?(%Handler{ref: ref}) do
    case ref do
      pid when is_pid(pid) -> Process.alive?(pid)
      _ -> false
    end
  end
end
