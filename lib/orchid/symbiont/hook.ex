defmodule Orchid.Symbiont.Hook do
  @behaviour Orchid.Runner.Hook

  @step_handlers :__orchid_symbiont__

  def call(ctx, next_fn) do
    if Orchid.Symbiont.Step.has_model?(ctx.step_implementation) do
      # ...

      next_fn.(ctx)
    else
      next_fn.(ctx)
    end
  end

  def inject_handlers(ctx, mode, key \\ @step_handlers)

  def inject_handlers(ctx, :recipe, key) do
    ctx.recipe_opts |> Keyword.get(key, %{})
  end

  def inject_handlers(ctx, :step_opts, key) do
    ctx.step_opts |> Keyword.get(key, %{})
  end
end
