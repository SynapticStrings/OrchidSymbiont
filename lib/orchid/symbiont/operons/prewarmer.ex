defmodule Orchid.Symbiont.Operons.Prewarmer do
  alias Orchid.Operon
  @behaviour Operon

  @impl true
  @spec call(Operon.Request.t(), (Operon.Request.t() -> Operon.Response.t())) :: Operon.Response.t()
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
