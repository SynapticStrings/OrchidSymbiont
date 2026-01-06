defmodule Orchid.Symbiont.Hooks.Injector do
  alias Orchid.Symbiont.Step, as: SymbiontStep
  @behaviour Orchid.Runner.Hook

  defmodule Adapter do
    use Orchid.Step

    @delegate_key :__symbiont_delegate__
    @handlers_key :__symbiont_handlers__

    def delegate_key, do: @delegate_key
    def handlers_key, do: @handlers_key

    @impl Orchid.Step
    def validate_options(step_options) do
      Keyword.has_key?(step_options, @delegate_key)
      |> case do
        true -> :ok
        false -> {:error, {:missing, @delegate_key}}
      end
    end

    @impl Orchid.Step
    def run(input, step_options) do
      {delegate_module, step_opts} = Keyword.pop(step_options, @delegate_key)

      handlers = Keyword.get(step_opts, @handlers_key, %{})

      delegate_module.run_with_model(input, handlers, step_opts)
    end
  end

  @spec call(Orchid.Runner.Context.t(), Orchid.Runner.Hook.next_fn()) ::
          {:ok, Orchid.Step.output()} | {:error, term()}
  def call(ctx, next_fn) do
    symbiont_step = ctx.step_implementation

    with true <- SymbiontStep.has_model?(symbiont_step),
         handlers when is_map(handlers) <- get_headers(symbiont_step, ctx.step_opts) do
      updated_ctx = %{
        ctx
        | step_implementation: Adapter,
          step_opts:
            Keyword.merge(
              ctx.step_opts,
              [
                # Implementation
                {Adapter.delegate_key(), symbiont_step},
                # Handler Map
                {Adapter.handlers_key(), handlers}
              ]
            )
      }

      next_fn.(updated_ctx)
    else
      false -> next_fn.(ctx)
      {:error, error} -> {:error, error}
    end
  end

  defp get_headers(symbiont_step, step_opts) do
    logical_names = symbiont_step.required()

    binding_key = SymbiontStep.get_required()
    bindings = Keyword.get(step_opts, binding_key, %{}) |> Map.new()

    Enum.reduce_while(logical_names, %{}, fn logical, acc ->
      external_name = Map.get(bindings, logical, logical)

      case Orchid.Symbiont.Resolver.resolve(external_name) do
        {:ok, handler} ->
          {:cont, Map.put(acc, logical, handler)}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end
end
