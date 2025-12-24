defmodule Orchid.Symbiont.Operons.Prewarmer do
  @behaviour Orchid.Operon

  @impl true
  def call(request, next_fn) do
    services_to_warm =
      request.recipe.steps
      |> Enum.map(fn step ->
        {impl, _, _} = Orchid.Step.extract_schema(step)

        if Orchid.Symbiont.Step.has_model?(impl) do
          impl.required()
        else
          []
        end
      end)
      |> List.flatten()
      |> Enum.uniq()

    Orchid.Symbiont.preload(services_to_warm)

    next_fn.(request)
  end
end
