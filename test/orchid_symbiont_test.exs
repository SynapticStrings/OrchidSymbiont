# test/symbiont_integration_test.exs
defmodule Orchid.Symbiont.Test do
  use ExUnit.Case, async: false

  # ==========================================
  # 1. 定义共生体 (The Worker)
  #    这是你要管理的“重型服务”，比如 Python/Nx
  # ==========================================
  defmodule MockWorker do
    use GenServer

    # 这里的 opts 会包含 {:via, Registry, ...}
    def start_link(opts) do
      name = Keyword.fetch!(opts, :name)
      GenServer.start_link(__MODULE__, [], name: name)
    end

    def init(state), do: {:ok, state}

    def handle_call({:process, input}, _from, state) do
      # 模拟耗时计算，返回处理后的结果
      result = "#{input}_processed"
      {:reply, {:ok, result}, state}
    end
  end

  # ==========================================
  # 2. 定义 Step (The Logic)
  #    这是 Orchid 的步骤，声明它需要什么服务
  # ==========================================
  defmodule MyImageStep do
    @behaviour Orchid.Symbiont.Step

    def required, do: [:model]

    def run_with_model(params, ports, _opts) do
      handler = ports.model

      {:ok, result} = Orchid.Symbiont.call(handler, {:process, Orchid.Param.get_payload(params)})

      {:ok, Orchid.Param.new(:result, :any, result)}
    end
  end

  # ==========================================
  # 3. 测试流程 (The Test)
  # ==========================================

  setup do
    # 确保 Runtime 已经启动 (在 application.ex 里应该加过了，这里防守一下)
    # 如果是纯新建的项目，可能需要手动 start_supervised
    # start_supervised!(Orchid.Symbiont.Runtime)
    :ok
  end

  test "complete flow: register -> resolve -> inject -> run" do
    # --- 准备阶段 (Simulation) ---

    # 1. 注册共生体 (Register)
    #    告诉系统：当有人要 :stable_diffusion 时，用 MockWorker 启动它
    :ok = Orchid.Symbiont.register(:stable_diffusion, {MockWorker, []})

    # --- 运行阶段 (Orchid Runner Simulation) ---

    # 2. 模拟 Hook：解析依赖 (Resolve)
    #    Step 里配置了 bind: [model: :stable_diffusion]
    #    Step 内部要 :model，我们把它映射到外部的 :stable_diffusion
    {:ok, handler} = Orchid.Symbiont.Resolver.resolve(:stable_diffusion)
    # 这里会触发按需启动！

    assert is_pid(handler.ref)
    assert Process.alive?(handler.ref)
    IO.puts(">> Symbiont 启动成功 PID: #{inspect(handler.ref)}")

    # 3. 真正运行 Step
    input_params = %{data: Orchid.Param.new(:data, :any, "input_img")}
    # orchid opts
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

    # --- 验证结果 ---
    assert "input_img_processed" == Orchid.Param.get_payload(result.result)
    IO.puts(">> Step 执行成功，结果: #{inspect(result)}")

    # --- 验证韧性 (Resilience) ---

    # 4. 模拟崩溃：杀掉 Worker 进程
    Process.exit(handler.ref, :kill)
    # 等待 Registry 清理
    Process.sleep(10)

    # 5. 再次解析：应该获得一个新的 PID
    {:ok, new_handler} = Orchid.Symbiont.Resolver.resolve(:stable_diffusion)

    assert new_handler.ref != handler.ref
    assert Process.alive?(new_handler.ref)
    IO.puts(">> Symbiont 重启成功 Old: #{inspect(handler.ref)} -> New: #{inspect(new_handler.ref)}")
  end
end
