defmodule OrchidSymbiont.Handler do
  @moduledoc """
  A struct representing a resolved symbiont reference.

  This struct wraps the process reference and provides metadata
  for communicating with the underlying worker.

  ## Fields

    * `:name` - The logical name of the symbiont
    * `:ref` - The process reference (PID or via-tuple)
    * `:adapter` - The module to use for communication (default: `GenServer`)
    * `:metadata` - Additional metadata about the handler

  ## Usage

  Use `OrchidSymbiont.call/3` to communicate with the worker:

      handler = %{name: :model, ref: pid, adapter: GenServer, metadata: %{}}
      OrchidSymbiont.call(handler, {:predict, input})
  """

  @type t :: %__MODULE__{
          name: term(),
          ref: {atom(), node()} | pid() | atom(),
          adapter: module(),
          metadata: map() | keyword() | nil
        }

  defstruct [:name, :ref, adapter: GenServer, metadata: %{}]
end
