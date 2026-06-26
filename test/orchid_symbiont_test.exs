defmodule OrchidSymbiont.Test do
  use ExUnit.Case, async: false
  require Logger

  defmodule MockWorker do
    use GenServer

    def start_link(opts) do
      case Keyword.get(opts, :name) do
        nil -> GenServer.start_link(__MODULE__, [])
        name -> GenServer.start_link(__MODULE__, [], name: name)
      end
    end

    def init(state), do: {:ok, state}

    def handle_call({:process, input}, _from, state) do
      result = "#{input}_processed"
      {:reply, {:ok, result}, state}
    end

    def handle_call(msg, _from, state) when is_binary(msg), do: {:reply, :ok, state}
  end

  defmodule MyImageStep do
    @behaviour OrchidSymbiont.Step

    def required, do: [:model]

    def run_with_model(params, ports, _opts) do
      handler = ports.model
      {:ok, result} = OrchidSymbiont.call(handler, {:process, Orchid.Param.get_payload(params)})
      {:ok, Orchid.Param.new(:result, :any, result)}
    end
  end

  setup context do
    scope_id = "scope_#{context.test}"

    start_supervised!({OrchidSymbiont.Runtime, scope_id: scope_id})

    %{scope_id: scope_id}
  end

  test "complete flow: register -> resolve -> inject -> run", %{scope_id: scope_id} do
    :ok = OrchidSymbiont.register(scope_id, "stable_diffusion", {MockWorker, []})

    # 2. 解析时也带上 scope_id
    {:ok, handler} = OrchidSymbiont.Resolver.resolve(scope_id, "stable_diffusion")

    assert is_pid(handler.ref)
    assert Process.alive?(handler.ref)
    Logger.info(">> Symbiont activated PID: #{inspect(handler.ref)}")

    input_params = %{data: Orchid.Param.new(:data, :any, "input_img")}

    opts = [
      baggage: %{scope_id: scope_id}
    ]

    {:ok, result} =
      Orchid.run(
        Orchid.Recipe.new([
          {MyImageStep, :data, :result,
           extra_hooks_stack: [OrchidSymbiont.Hooks.Injector],
           symbiont_mapper: [model: "stable_diffusion"]}
        ]),
        input_params,
        opts
      )

    assert "input_img_processed" == Orchid.Param.get_payload(result.result)
    Logger.info(">> Step execute success with result: #{inspect(result)}")

    Process.exit(handler.ref, :kill)
    Process.sleep(10)

    {:ok, new_handler} = OrchidSymbiont.Resolver.resolve(scope_id, "stable_diffusion")

    assert new_handler.ref != handler.ref
    assert Process.alive?(new_handler.ref)

    Logger.info(
      ">> Symbiont re-activated successfully\n\nOld: #{inspect(handler.ref)} -> New: #{inspect(new_handler.ref)}"
    )
  end

  test "auto shutdown on idle (TTL)", %{scope_id: scope_id} do
    :ok = OrchidSymbiont.register(scope_id, "fast_worker", {MockWorker, [ttl: 100]})

    {:ok, handler} = OrchidSymbiont.Resolver.resolve(scope_id, "fast_worker")
    pid = handler.ref
    assert Process.alive?(pid)

    OrchidSymbiont.call(handler, "keep_alive")
    Process.sleep(50)
    assert Process.alive?(pid)

    OrchidSymbiont.call(handler, "keep_alive_again")
    Process.sleep(150)

    refute Process.alive?(pid)

    assert [] == Registry.lookup(OrchidSymbiont.Registry, {scope_id, "fast_worker"})

    {:ok, new_handler} = OrchidSymbiont.Resolver.resolve(scope_id, "fast_worker")
    assert new_handler.ref != pid
  end

  test "scopes are completely isolated" do
    scope_a = "project_a_scope"
    scope_b = "project_b_scope"

    start_supervised!(
      Supervisor.child_spec({OrchidSymbiont.Runtime, scope_id: scope_a}, id: scope_a)
    )

    start_supervised!(
      Supervisor.child_spec({OrchidSymbiont.Runtime, scope_id: scope_b}, id: scope_b)
    )

    :ok = OrchidSymbiont.register(scope_a, "shared_name_worker", {MockWorker, []})
    {:ok, handler_a} = OrchidSymbiont.Resolver.resolve(scope_a, "shared_name_worker")

    assert {:error, {:unknown_symbiont, "shared_name_worker"}} ==
             OrchidSymbiont.Resolver.resolve(scope_b, "shared_name_worker")

    :ok = OrchidSymbiont.register(scope_b, "shared_name_worker", {MockWorker, []})
    {:ok, handler_b} = OrchidSymbiont.Resolver.resolve(scope_b, "shared_name_worker")

    assert handler_a.ref != handler_b.ref
    assert Process.alive?(handler_a.ref)
    assert Process.alive?(handler_b.ref)
  end

  # ── strict_mode ────────────────────────────────────────

  describe "strict_mode" do
    test "prevents fallback to global catalog", %{scope_id: scope_id} do
      # Register in the globally-running runtime (started by Application)
      :ok = OrchidSymbiont.register("global_model", {MockWorker, []})

      # scope has NO registration for this model
      # strict_mode: true should fail with strict_mode_violation
      assert {:error, {:strict_mode_violation, msg}} =
               OrchidSymbiont.Resolver.resolve(scope_id, "global_model", strict_mode: true)

      assert msg =~ "global_model"
      assert msg =~ scope_id
    end

    test "without strict_mode, falls back to global", %{scope_id: scope_id} do
      :ok = OrchidSymbiont.register("shared_service", {MockWorker, []})

      # scope has NO registration, but global does
      # strict_mode default (false) falls back to global succeeds
      {:ok, handler} = OrchidSymbiont.Resolver.resolve(scope_id, "shared_service")

      assert is_pid(handler.ref)
      assert Process.alive?(handler.ref)
    end

    test "strict_mode: true in baggage, scoped registration succeeds", %{scope_id: scope_id} do
      # Register ONLY in scope
      :ok = OrchidSymbiont.register(scope_id, "my_model", {MockWorker, []})

      input_params = %{data: Orchid.Param.new(:data, :any, "hello")}

      {:ok, result} =
        Orchid.run(
          Orchid.Recipe.new([
            {MyImageStep, :data, :result,
             extra_hooks_stack: [OrchidSymbiont.Hooks.Injector],
             symbiont_mapper: [model: "my_model"]}
          ]),
          input_params,
          baggage: %{scope_id: scope_id, strict_mode: true}
        )

      assert "hello_processed" == Orchid.Param.get_payload(result.result)
    end

    test "strict_mode: true blocks global fallback via Injector", %{scope_id: scope_id} do
      # Register ONLY globally
      :ok = OrchidSymbiont.register("global_only", {MockWorker, []})

      input_params = %{data: Orchid.Param.new(:data, :any, "data")}

      # strict_mode: true scope has no registration should fail
      {:error, %Orchid.Error{reason: {:strict_mode_violation, msg}}} =
        Orchid.run(
          Orchid.Recipe.new([
            {MyImageStep, :data, :result,
             extra_hooks_stack: [OrchidSymbiont.Hooks.Injector],
             symbiont_mapper: [model: "global_only"]}
          ]),
          input_params,
          baggage: %{scope_id: scope_id, strict_mode: true}
        )

      assert msg =~ "global_only"
      assert msg =~ scope_id
    end

    test "strict_mode: false allows global fallback via Injector", %{scope_id: scope_id} do
      :ok = OrchidSymbiont.register("fallback_model", {MockWorker, []})

      input_params = %{data: Orchid.Param.new(:data, :any, "world")}

      {:ok, result} =
        Orchid.run(
          Orchid.Recipe.new([
            {MyImageStep, :data, :result,
             extra_hooks_stack: [OrchidSymbiont.Hooks.Injector],
             symbiont_mapper: [model: "fallback_model"]}
          ]),
          input_params,
          baggage: %{scope_id: scope_id, strict_mode: false}
        )

      assert "world_processed" == Orchid.Param.get_payload(result.result)
    end
  end
end
