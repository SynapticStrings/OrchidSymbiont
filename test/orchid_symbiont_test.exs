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
    session_id = "session_#{context.test}"

    start_supervised!({OrchidSymbiont.Runtime, session_id: session_id})

    %{session_id: session_id}
  end

  test "complete flow: register -> resolve -> inject -> run", %{session_id: session_id} do
    :ok = OrchidSymbiont.register(session_id, :stable_diffusion, {MockWorker, []})

    # 2. 解析时也带上 session_id
    {:ok, handler} = OrchidSymbiont.Resolver.resolve(session_id, :stable_diffusion)

    assert is_pid(handler.ref)
    assert Process.alive?(handler.ref)
    Logger.info(">> Symbiont activated PID: #{inspect(handler.ref)}")

    input_params = %{data: Orchid.Param.new(:data, :any, "input_img")}

    opts = [
      baggage: %{session_id: session_id}
    ]

    {:ok, result} =
      Orchid.run(
        Orchid.Recipe.new([
          {MyImageStep, :data, :result,
           extra_hooks_stack: [OrchidSymbiont.Hooks.Injector],
           symbiont_mapper: [model: :stable_diffusion]}
        ]),
        input_params,
        opts
      )

    assert "input_img_processed" == Orchid.Param.get_payload(result.result)
    Logger.info(">> Step execute success with result: #{inspect(result)}")

    Process.exit(handler.ref, :kill)
    Process.sleep(10)

    {:ok, new_handler} = OrchidSymbiont.Resolver.resolve(session_id, :stable_diffusion)

    assert new_handler.ref != handler.ref
    assert Process.alive?(new_handler.ref)
    Logger.info(">> Symbiont re-activated successfully\n\nOld: #{inspect(handler.ref)} -> New: #{inspect(new_handler.ref)}")
  end

  test "auto shutdown on idle (TTL)", %{session_id: session_id} do
    :ok = OrchidSymbiont.register(session_id, :fast_worker, {MockWorker, [ttl: 100]})

    {:ok, handler} = OrchidSymbiont.Resolver.resolve(session_id, :fast_worker)
    pid = handler.ref
    assert Process.alive?(pid)

    OrchidSymbiont.call(handler, "keep_alive")
    Process.sleep(50)
    assert Process.alive?(pid)

    OrchidSymbiont.call(handler, "keep_alive_again")
    Process.sleep(150)

    refute Process.alive?(pid)

    assert [] == Registry.lookup(OrchidSymbiont.Registry, {session_id, :fast_worker})

    {:ok, new_handler} = OrchidSymbiont.Resolver.resolve(session_id, :fast_worker)
    assert new_handler.ref != pid
  end

  test "sessions are completely isolated" do
    session_a = "project_a_session"
    session_b = "project_b_session"

    start_supervised!(Supervisor.child_spec({OrchidSymbiont.Runtime, session_id: session_a}, id: session_a))
    start_supervised!(Supervisor.child_spec({OrchidSymbiont.Runtime, session_id: session_b}, id: session_b))

    :ok = OrchidSymbiont.register(session_a, :shared_name_worker, {MockWorker, []})
    {:ok, handler_a} = OrchidSymbiont.Resolver.resolve(session_a, :shared_name_worker)

    assert {:error, {:unknown_symbiont, :shared_name_worker}} ==
             OrchidSymbiont.Resolver.resolve(session_b, :shared_name_worker)

    :ok = OrchidSymbiont.register(session_b, :shared_name_worker, {MockWorker, []})
    {:ok, handler_b} = OrchidSymbiont.Resolver.resolve(session_b, :shared_name_worker)

    assert handler_a.ref != handler_b.ref
    assert Process.alive?(handler_a.ref)
    assert Process.alive?(handler_b.ref)
  end
end
