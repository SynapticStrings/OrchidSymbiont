defmodule Orchid.Symbiont.Test do
  use ExUnit.Case, async: false

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
    @behaviour Orchid.Symbiont.Step

    def required, do: [:model]

    def run_with_model(params, ports, _opts) do
      handler = ports.model

      {:ok, result} = Orchid.Symbiont.call(handler, {:process, Orchid.Param.get_payload(params)})

      {:ok, Orchid.Param.new(:result, :any, result)}
    end
  end

  setup do
    :ok
  end

  test "complete flow: register -> resolve -> inject -> run" do
    :ok = Orchid.Symbiont.register(:stable_diffusion, {MockWorker, []})

    # Will activate here
    {:ok, handler} = Orchid.Symbiont.Resolver.resolve(:stable_diffusion)

    assert is_pid(handler.ref)
    assert Process.alive?(handler.ref)
    IO.puts(">> Symbiont avtivate\d\dPID: #{inspect(handler.ref)}")

    input_params = %{data: Orchid.Param.new(:data, :any, "input_img")}
    opts = []

    {:ok, result} =
      Orchid.run(
        Orchid.Recipe.new([
          {MyImageStep, :data, :result,
           extra_hooks_stack: [Orchid.Symbiont.Hooks.Injector],
           symbiont_mapper: [model: :stable_diffusion]}
        ]),
        input_params,
        opts
      )
    assert "input_img_processed" == Orchid.Param.get_payload(result.result)
    IO.puts(">> Step execute success with result: #{inspect(result)}")

    Process.exit(handler.ref, :kill)
    # waiting for Registry cleanup
    Process.sleep(10)

    {:ok, new_handler} = Orchid.Symbiont.Resolver.resolve(:stable_diffusion)

    assert new_handler.ref != handler.ref
    assert Process.alive?(new_handler.ref)
    IO.puts(">> Symbiont re-activated successfully\n\nOld: #{inspect(handler.ref)} -> New: #{inspect(new_handler.ref)}")
  end

  test "auto shutdown on idle (TTL)" do
    :ok = Orchid.Symbiont.register(:fast_worker, {MockWorker, [ttl: 100]})

    {:ok, handler} = Orchid.Symbiont.Resolver.resolve(:fast_worker)
    pid = handler.ref
    assert Process.alive?(pid)

    Orchid.Symbiont.call(handler, "keep_alive")
    Process.sleep(50)
    assert Process.alive?(pid)

    Orchid.Symbiont.call(handler, "keep_alive_again")

    Process.sleep(150)

    refute Process.alive?(pid)

    assert [] == Registry.lookup(Orchid.Symbiont.Registry, :fast_worker)

    {:ok, new_handler} = Orchid.Symbiont.Resolver.resolve(:fast_worker)
    assert new_handler.ref != pid
  end
end
