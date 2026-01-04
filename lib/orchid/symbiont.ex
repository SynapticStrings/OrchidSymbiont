defmodule Orchid.Symbiont do
  alias Orchid.Symbiont.{Step, Handler, Preloader, Resolver, Catalog}

  @spec register(Step.symbiont_name(), {module(), any()}) :: :ok
  defdelegate register(name, mod_and_args), to: Catalog

  @spec preload([Step.symbiont_name()] | Step.symbiont_name()) :: :ok
  def preload(names) when is_list(names), do: Enum.each(names, &do_preload/1)
  def preload(name) when not is_list(name), do: do_preload(name)

  defp do_preload(name) do
    Task.Supervisor.start_child(Preloader, fn ->
      case Resolver.resolve(name) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          require Logger

          Logger.warning(
            "[OrchidSymbiont] Preload failed for #{inspect(name)}: #{inspect(reason)}"
          )
      end
    end)
  end

  @doc """
  Sends a request to the symbiont handler and waits for a response.
  """
  @spec call(Handler.t(), term(), timeout()) :: any()
  def call(%Handler{ref: pid, adapter: adapter}, request, timeout \\ 5000) do
    apply(adapter, :call, [pid, request, timeout])
  end
end
