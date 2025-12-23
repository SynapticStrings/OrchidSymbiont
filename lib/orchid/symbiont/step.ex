defmodule Orchid.Symbiont.Step do
  @type symbiont_name :: atom()
  @type symbiont_map :: %{symbiont_name() => Orchid.Symbiont.Handler.t()}

  @callback required() :: [symbiont_name()]

  @callback run_with_model(Orchid.Step.input(), symbiont_map(), Orchid.Step.step_options()) ::
              Orchid.Step.output()

  def has_model?(step), do: is_atom(step) and function_exported?(step, :run_with_model, 3)
end
