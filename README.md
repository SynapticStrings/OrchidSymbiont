# OrchidSymbiont

**Lazy Dependency Injection & Process Management for [Orchid](https://github.com/SynapticStrings/Orchid).**

OrchidSymbiont acts as a sidecar for your Orchid workflows. It allows individual steps to declare requirements for specific background services (GenServers). Symbiont ensures these services are **started on-demand (Just-In-Time)**, resolved, and injected directly into your step's execution context.

> **Why?** Perfect for steps requiring heavy resources (ML Models, Database Workers, Persistent Connections) that you don't want to keep running when the workflow is idle.

## Features

* **Lazy Loading**: Processes are only started when a Step actually needs them.
* **Automatic Registry**: Handles process registration, lookup, and idempotency (won't start twice).
* **Seamless Injection**: Injects process references(PID) directly into the step logic via a specialized Hook.
* **Blueprint Catalog**: Decouple service implementation from step definition.

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:orchid, "~> 0.5"}
    {:orchid_symbiont, "~> 0.1.2"}
  ]
end
```

Ensure `Orchid.Symbiont.Application` is started in your supervision tree (usually handled automatically by Mix).

## Usage

### 1. Register Symbionts

Tell Symbiont how to start your service. You usually do this in your application startup.

```elixir
# Register a logical name to a GenServer spec
# :heavy_calculator maps to {MyCalculatorWorker, [init_arg: :foo]}
Orchid.Symbiont.register(:heavy_calculator, {MyCalculatorWorker, [init_arg: :foo]})
```

### 2. Define Steps

Implement the `Orchid.Symbiont.Step` behaviour. Note that we use `run_with_model/3` instead of the standard `run/2`.

```elixir
defmodule MyWorkflow.CalculateStep do
  # Use the behaviour
  @behaviour Orchid.Symbiont.Step

  # 1. Declare what you need
  @impl true
  def required, do: [:heavy_calculator]

  # 2. Use it (handlers contains the PIDs)
  @impl true
  def run_with_model(input, handlers, _opts) do
    # Get the resolved service reference
    worker = handlers[:heavy_calculator] 

    result = Orchid.Symbiont.call(worker, {:compute, input})
    
    {:ok, result}
  end
end
```

### 3. Run with Hook

Inject the `Orchid.Symbiont.Hooks.Injector` into your recipe's step configuration.

```elixir
step_opts = [
  # This hook activates the Symbiont logic
  extra_hooks_stack: [Orchid.Symbiont.Hooks.Injector] 
]

steps = [
  {MyWorkflow.CalculateStep, :input_data, :output_result, step_opts}
]

recipe = Orchid.Recipe.new(steps, name: :smart_calculation)

Orchid.run(recipe, inputs)
```

## How it works

1.  **Intercept**: The `Orchid.Symbiont.Hooks.Injector` pauses the step execution.
2.  **Check**: It reads the `required()` list from your step.
3.  **Resolve**: 
  * Checks `Orchid.Symbiont.Registry` if the service is alive.
  * If not, it looks up the blueprint in the **Catalog** and starts it under a `DynamicSupervisor`.
4.  **Inject**: The `PID` is wrapped in a `Handler` struct and passed to `run_with_model`.
