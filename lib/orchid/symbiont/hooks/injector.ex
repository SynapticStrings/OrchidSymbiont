defmodule Orchid.Symbiont.Hooks.Injector do
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

  def call(ctx, next_fn) do
    symbiont_step = ctx.step_implementation

    with true <- Orchid.Symbiont.Step.has_model?(symbiont_step),
         [] = handlers <- get_headers(symbiont_step, ctx.step_opts) do
      next_fn.(%{
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
      })
    else
      false -> next_fn.(ctx)
      {:error, error} -> error
    end
  end

  defp get_headers(symbiont_step, step_opts) do
    logical_names = symbiont_step.required()

    binding_key = Orchid.Symbiont.Step.get_step_required_mapper()
    bindings = Keyword.get(step_opts, binding_key, %{}) |> Map.new()

    Enum.reduce_while(logical_names, [], fn logical, acc ->
      external_name = Map.get(bindings, logical, logical)

      case Orchid.Symbiont.Resolver.resolve(external_name) do
        {:ok, handler} ->
          {:cont, [{logical, handler} | acc]}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end
end
