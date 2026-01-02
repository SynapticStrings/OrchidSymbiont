defmodule OrchidSymbiont.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/SynapticStrings/OrchidSymbiont"

  def project do
    [
      app: :orchid_symbiont,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Orchid.Symbiont.Application, []}
    ]
  end

  defp description do
    """
    Lazy dependency injection and process management extension for Orchid workflow engine.
    Supports on-demand GenServer starting (Symbionts) and transparent injection into Steps.
    """
  end

  defp package do
    [
      name: "orchid_symbiont",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Orchid Core" => "https://hex.pm/packages/orchid"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:orchid, "~> 0.5"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
