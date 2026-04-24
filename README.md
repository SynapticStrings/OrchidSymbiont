# OrchidSymbiont

**Lazy Dependency Injection & Process Management for [Orchid](https://github.com/SynapticStrings/Orchid).**

OrchidSymbiont acts as a sidecar for your Orchid workflows. It allows individual steps to declare requirements for specific background services (GenServers). Symbiont ensures these services are **started on-demand (Just-In-Time)**, resolved, and injected directly into your step's execution context.

> **Why?** Perfect for steps requiring heavy resources (ML Models, Database Workers, Persistent Connections) that you don't want to keep running when the workflow is idle.

## Features

* **Lazy Loading**: Processes are only started when a Step actually needs them.
* **Automatic Registry**: Handles process registration, lookup, and idempotency (won't start twice).
* **Seamless Injection**: Injects process references(PID) directly into the step logic via a specialized Hook.
* **Blueprint Catalog**: Decouple service implementation from step definition.
* **Session Isolation (Multi-Tenancy)** *(New in 0.2.0)*: Run completely isolated sandboxes of your services for different tenants or concurrent workflows.

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:orchid, "~> 0.6"},
    {:orchid_symbiont, "~> 0.2"}
  ]
end
```

Ensure `Application` is started in your supervision tree (handled automatically for the global default namespace).

## Usage

### 1. Register Symbionts (Global)

Tell Symbiont how to start your service.

```elixir
# Register a logical name to a GenServer spec
# :heavy_calculator maps to {MyCalculatorWorker, [init_arg: :foo]}
OrchidSymbiont.register(:heavy_calculator, {MyCalculatorWorker, [init_arg: :foo]})
```

### 2. Define Steps

Implement the `OrchidSymbiont.Step` behaviour. Note that we use `run_with_model/3` instead of the standard `run/2`.

```elixir
defmodule MyWorkflow.CalculateStep do
  @behaviour OrchidSymbiont.Step

  @impl true
  def required, do: [:heavy_calculator]

  @impl true
  def run_with_model(input, handlers, _opts) do
    # Get the resolved service reference
    worker = handlers[:heavy_calculator] 

    result = OrchidSymbiont.call(worker, {:compute, input})
    
    {:ok, result}
  end
end
```

### 3. Run with Hook

Inject the `OrchidSymbiont.Hooks.Injector` into your recipe's step configuration.

```elixir
step_opts = [
  # This hook activates the Symbiont logic
  extra_hooks_stack: [OrchidSymbiont.Hooks.Injector] 
]

# ... define steps and recipe ...

Orchid.run(recipe, inputs)
```

---

## 🚀 Advanced: Scope Isolation (New in 0.2.x)

If you are building a SaaS application or need completely isolated environments for different workflows, you can use **Scope**. 

A Session creates a dedicated, dynamically named `Registry`, `DynamicSupervisor`, and `Catalog`. Processes running in `"scope_a"` cannot see or conflict with processes in `"scope_b"`, even if they share the same logical names!

### 1. Start a Session Runtime

You must start a Runtime for your specific session in your application's supervision tree (or dynamically):

```elixir
# Start an isolated environment for a specific project/tenant
children = [
  {OrchidSymbiont.Runtime, scope_id: "project_a_session"}
]
Supervisor.start_link(children, strategy: :one_for_one)
```

### 2. Register for a specific Session

You can register blueprints globally (without a session ID) or specifically for a session. 
*Note: If a session cannot find a blueprint in its own catalog, it will smartly fall back to the global catalog!*

```elixir
# Register specifically for project_a_session
OrchidSymbiont.register("project_a_session", :heavy_calculator, {MyCustomWorker, []})
```

### 3. Run the Workflow in a Session

To tell the Symbiont Injector Hook to use a specific session, simply pass the `scope_id` into the Orchid `WorkflowCtx` baggage:

```elixir
workflow_ctx = Orchid.WorkflowCtx.new()
  |> Orchid.WorkflowCtx.put_baggage(:scope_id, "project_a_session") # <-- Tell Symbiont to use this sandbox

Orchid.run(recipe, inputs, workflow_ctx: workflow_ctx)
```

That's it! Symbiont will now automatically resolve and start processes under the isolated `"project_a_session"` supervision tree.

---

## How it works

1.  **Intercept**: The `OrchidSymbiont.Hooks.Injector` pauses the step execution.
2.  **Check**: It reads the `required()` list from your step and looks for a `:scope_id` in the workflow baggage.
3.  **Resolve**: 
  * Uses the `Naming` module to route to the correct `Registry` and `Catalog` based on the session ID.
  * Checks if the service is alive. If not, looks up the blueprint and starts it under the isolated `DynamicSupervisor`.
4.  **Inject**: The `PID` is wrapped in a `Handler` struct and passed to `run_with_model`.
