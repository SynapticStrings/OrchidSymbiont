defmodule Orchid.Symbiont do
  defdelegate register(name, mod_and_args), to: Orchid.Symbiont.Catalog

  def preload(names) when is_list(names) do
    Enum.each(names, fn name ->
      Task.Supervisor.start_child(Orchid.Symbiont.Preloader, fn ->
        case Orchid.Symbiont.Resolver.resolve(name) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            require Logger

            Logger.warning(
              "[OrchidSymbiont] Preload failed for #{inspect(name)}: #{inspect(reason)}"
            )
        end
      end)
    end)
  end

  def call(%Orchid.Symbiont.Handler{ref: pid, adapter: adapter}, request, timeout \\ 5000) do
    adapter.call(pid, request, timeout)
  end
end
