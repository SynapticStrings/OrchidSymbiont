defmodule Orchid.Symbiont do
  defdelegate register(name, mod_and_args), to: Orchid.Symbiont.Catalog

  def call(%Orchid.Symbiont.Handler{ref: pid, adapter: GenServer}, request, timeout \\ 5000) do
    GenServer.call(pid, request, timeout)
  end
end
