defmodule Orchid.Symbiont.Application do
  use Application

  @impl true
  def start(_type, _args), do: Orchid.Symbiont.Runtime.start_link([])
end
