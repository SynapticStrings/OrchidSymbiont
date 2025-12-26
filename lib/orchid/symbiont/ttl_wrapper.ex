defmodule Orchid.Symbiont.TTLWrapper do
  use GenServer

  defstruct [:worker_pid, :ttl]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :name))
  end

  @impl true
  def init(opts) do
    mod = Keyword.fetch!(opts, :worker_mod)
    args = Keyword.fetch!(opts, :worker_args)
    ttl = Keyword.get(opts, :ttl, :infinity)

    Process.flag(:trap_exit, true)

    case mod.start_link(args) do
      {:ok, pid} ->
        {:ok, %__MODULE__{worker_pid: pid, ttl: ttl}, ttl}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(request, _from, state) do
    try do
      result = GenServer.call(state.worker_pid, request, :infinity)
      {:reply, result, state, state.ttl}
    catch
      :exit, reason -> {:stop, reason, {:exit, reason}, state}
    end
  end

  @impl true
  def handle_cast(request, state) do
    GenServer.cast(state.worker_pid, request)
    {:noreply, state, state.ttl}
  end

  @impl true
  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, state) when pid == state.worker_pid do
    {:stop, reason, state}
  end
end
