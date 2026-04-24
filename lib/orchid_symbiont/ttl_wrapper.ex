defmodule OrchidSymbiont.TTLWrapper do
  @moduledoc """
  A GenServer wrapper that auto-terminates idle workers.

  This wrapper monitors the wrapped worker and will automatically
  shut it down after a period of inactivity (TTL). Each request
  resets the idle timer.

  ## Options

    * `:name` - The via-tuple name for registration (required)
    * `:worker_mod` - The module to start (required)
    * `:worker_args` - Arguments to pass to the worker's start_link (required)
    * `:ttl` - Idle timeout in milliseconds (default: `:infinity`)

  ## How It Works

  The wrapper starts the actual worker as a linked process. On each
  `handle_call`, the TTL timer is reset. If no requests are received
  within the TTL period, the worker is terminated.

  The wrapper traps exits to properly handle worker crashes.
  """

  use GenServer

  defstruct [:worker_pid, :ttl]

  @doc """
  Starts the TTL wrapper with the given options.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
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
