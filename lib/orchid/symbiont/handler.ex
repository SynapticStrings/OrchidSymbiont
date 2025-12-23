defmodule Orchid.Symbiont.Handler do
  @type t :: %__MODULE__{
    name: term(),
    ref: {atom(), node()} | pid() | atom(),
    adapter: module(),
    metadata: map() | keyword() | nil
  }
  defstruct [:name, :ref, adapter: GenServer, metadata: %{}]
end
