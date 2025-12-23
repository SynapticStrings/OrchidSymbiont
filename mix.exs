defmodule OrchidSymbiont.MixProject do
  use Mix.Project

  def project do
    [
      app: :orchid_symbiont,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Orchid.Symbiont.Runtime, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:orchid, "~> 0.3.5"}
    ]
  end
end
