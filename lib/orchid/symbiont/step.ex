defmodule Orchid.Symbiont.Step do
  @moduledoc """
  ...

  ## Examples

      {
        CustomeStep,
        :input, :output,
        [{Orchid.Symbiont.Step.get_required(), [foo: :bar]}]
      }
  """

  @type symbiont_name :: atom()
  @type symbiont_map :: %{symbiont_name() => Orchid.Symbiont.Handler.t()}

  @callback required() :: [symbiont_name()]

  @step_required_mapper :symbiont_mapper

  def get_required, do: @step_required_mapper

  @callback run_with_model(Orchid.Step.input(), symbiont_map(), Orchid.Step.step_options()) ::
              Orchid.Step.output()

  def has_model?(step),
    do:
      is_atom(step) and
        function_exported?(step, :required, 0) and
        function_exported?(step, :run_with_model, 3)
end
