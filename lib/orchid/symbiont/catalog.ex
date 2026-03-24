defmodule OrchidSymbiont.Catalog do
  use GenServer

  @type sesssion_id:: binary()
  @type name :: {sesssion_id(), OrchidSymbiont.Step.symbiont_name()}

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec register(name() | OrchidSymbiont.Step.symbiont_name(), {module(), term()}) :: any()
  def register(name, {mod, args}) do
    GenServer.call(__MODULE__, {:register, name, {mod, args}})
  end

  @spec lookup(OrchidSymbiont.Step.symbiont_name()) :: any()
  def lookup(name) do
    GenServer.call(__MODULE__, {:lookup, name})
  end

  @spec lookup(sesssion_id(), OrchidSymbiont.Step.symbiont_name()) :: any()
  def lookup(session_id, name) when not is_nil(session_id) do
    GenServer.call(__MODULE__, {:lookup, {session_id, name}})
    |> case do
      nil -> GenServer.call(__MODULE__, {:lookup, name})
      res -> res
    end
  end

  @spec clear_session(sesssion_id()) :: :ok
  def clear_session(session_id) do
    GenServer.cast(__MODULE__, {:clear, session_id})
  end

  @spec clear() :: :ok
  def clear do
    GenServer.cast(__MODULE__, :clear_all)
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

  @impl true
  def handle_cast({:clear, session}, state) when not is_tuple(session) do
    {:noreply, Map.reject(state, fn {{session_id, _logical}, _v} -> session_id == session end)}
  end

  @impl true
  def handle_cast(:clear_all, _state) do
    {:noreply, %{}}
  end
end
