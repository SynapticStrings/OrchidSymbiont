defmodule Orchid.Symbiont.Hook do
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
    if Orchid.Symbiont.Step.has_model?(symbiont_step) do
      logical_names = symbiont_step.required()

      binding_key = Orchid.Symbiont.Step.get_step_required_mapper()
      bindings = Keyword.get(ctx.step_opts, binding_key, %{}) |> Map.new()

      handlers = Map.new(logical_names, fn logical ->
        external_name = Map.get(bindings, logical, logical)

        # if cought error, fast failed.
        {:ok, handler} = Orchid.Symbiont.Resolver.resolve(external_name)

        {logical, handler}
      end)

      next_fn.(%{
        ctx
        | step_implementation: Adapter,
          step_opts: Keyword.merge(
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
      next_fn.(ctx)
    end
  end

  def inject_handlers(ctx, mode, key \\ Adapter.handlers_key())

  def inject_handlers(ctx, :recipe, key) do
    ctx.recipe_opts |> Keyword.get(key, %{})
  end

  def inject_handlers(ctx, :step_opts, key) do
    ctx.step_opts |> Keyword.get(key, %{})
  end
end
