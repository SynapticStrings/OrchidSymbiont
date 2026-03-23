defmodule Orchid.Symbiont.Catalog do
  use GenServer
  alias Orchid.Symbiont.Naming

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  def register(session_id \\ nil, name, {mod, args}) when is_atom(name) do
    GenServer.call(Naming.catalog(session_id), {:register, name, {mod, args}})
  end

  def lookup(nil, name) do
    GenServer.call(Naming.catalog(nil), {:lookup, name})
  end

  def lookup(session_id, name) when not is_nil(session_id) do
    GenServer.call(Naming.catalog(session_id), {:lookup, name})
    |> case do
      nil -> GenServer.call(Naming.catalog(nil), {:lookup, name})
      res -> res
    end
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:register, name, spec}, _from, state) do
    {:reply, :ok, Map.put(state, name, spec)}
  end

  @impl true
  def handle_call({:lookup, name}, _from, state) do
    {:reply, Map.get(state, name), state}
  end
end
