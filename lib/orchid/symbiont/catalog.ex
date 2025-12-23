defmodule Orchid.Symbiont.Catalog do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def register(name, {mod, args}) when is_atom(name) do
    GenServer.call(__MODULE__, {:register, name, {mod, args}})
  end

  def lookup(name) do
    GenServer.call(__MODULE__, {:lookup, name})
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
