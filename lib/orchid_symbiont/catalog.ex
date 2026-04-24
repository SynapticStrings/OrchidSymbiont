defmodule OrchidSymbiont.Catalog do
  @moduledoc """
  A blueprint registry for symbiont workers.

  Stores the module and startup arguments (blueprint) for each named symbiont.
  Acts as a lookup table that the Resolver uses to start workers on-demand.

  ## Scope Support

  Can be started globally or per-scope. When started with a `scope_id`,
  the catalog is isolated to that scope and won't conflict with others.

  ## Global Fallback

  Scoped catalogs will fall back to the global catalog if a blueprint
  is not found locally, allowing DRY registration patterns.
  """
  use Agent

  @doc """
  Starts the catalog agent.

  If `scope_id` is provided, creates an isolated catalog for that scope.
  Otherwise, starts the global catalog.
  """
  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(opts) do
    case Keyword.get(opts, :scope_id) do
      nil ->
        Agent.start_link(fn -> %{} end, name: __MODULE__)

      scope_id ->
        name = OrchidSymbiont.Naming.catalog(scope_id)
        Agent.start_link(fn -> %{} end, name: name)
    end
  end

  @doc """
  Looks up a blueprint by key.

  Returns `{:ok, value}` if found, or `:not_found` if the key
  doesn't exist in the catalog.
  """
  @spec lookup(atom(), term()) :: {:ok, term()} | :not_found
  def lookup(name \\ __MODULE__, key) do
    case Agent.get(name, &Map.get(&1, key)) do
      nil -> :not_found
      val -> {:ok, val}
    end
  end

  @doc """
  Registers a blueprint for a given key.

  The value is typically a tuple `{module, args}` describing how to start
  the worker.
  """
  @spec register(atom(), term(), term()) :: :ok
  def register(name \\ __MODULE__, key, value) do
    Agent.update(name, &Map.put(&1, key, value))
  end

  @doc """
  Dumps all blueprints from the catalog.
  """
  @spec dump(atom()) :: map()
  def dump(name \\ __MODULE__), do: Agent.get(name, & &1)

  @doc """
  Restores the catalog state from a previously dumped map.
  """
  @spec restore(atom(), map()) :: :ok
  def restore(name \\ __MODULE__, data), do: Agent.update(name, fn _ -> data end)
end
