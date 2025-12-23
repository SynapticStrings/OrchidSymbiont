defmodule Orchid.Symbiont do
  defdelegate register(name, mod_and_args), to: Orchid.Symbiont.Catalog

  def call(%Orchid.Symbiont.Handler{ref: pid, adapter: adapter}, request, timeout \\ 5000) do
    adapter.call(pid, request, timeout)
  end
end
