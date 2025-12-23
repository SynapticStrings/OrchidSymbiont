defmodule DummyStep do
  @behaviour Orchid.Symbiont.Step

  def required, do: []

  def run_with_model(_inputs, _symbiont_map, _opts) do
    # ...
  end
end
