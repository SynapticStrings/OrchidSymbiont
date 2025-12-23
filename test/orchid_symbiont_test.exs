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
    # 模拟引用了 use Orchid.Symbiont.Step
    @behaviour Orchid.Symbiont.Step

    # 声明：我内部逻辑名叫 :model
    def required, do: [:model]

    # 3参数 Run：由 Macro/Hook 转换而来
    def run_with_model(params, ports, _opts) do
      # 获取注入的 Handler
      handler = ports.model

      # 调用共生体
      {:ok, result} = Orchid.Symbiont.call(handler, {:process, params.data})

      {:ok, %{result: result}}
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
    #    假设 Recipe 里配置了 bind: [model: :stable_diffusion]
    #    Step 内部要 :model，我们把它映射到外部的 :stable_diffusion
    logical_name = :model
    external_name = :stable_diffusion

    # 这里会触发按需启动！
    {:ok, handler} = Orchid.Symbiont.Resolver.resolve(external_name)

    assert is_pid(handler.ref)
    assert Process.alive?(handler.ref)
    IO.puts(">> Symbiont 启动成功 PID: #{inspect(handler.ref)}")

    # 3. 模拟 Hook：构造 ports Map (Injection)
    ports = %{logical_name => handler}

    # 4. 真正运行 Step
    input_params = %{data: "input_img"}
    opts = [] # orchid opts

    result = MyImageStep.run_with_model(input_params, ports, opts)

    # --- 验证结果 ---
    assert {:ok, %{result: "input_img_processed"}} == result
    IO.puts(">> Step 执行成功，结果: #{inspect(result)}")

    # --- 验证韧性 (Resilience) ---

    # 5. 模拟崩溃：杀掉 Worker 进程
    Process.exit(handler.ref, :kill)
    # 等待 Registry 清理
    Process.sleep(10)

    # 6. 再次解析：应该获得一个新的 PID
    {:ok, new_handler} = Orchid.Symbiont.Resolver.resolve(external_name)

    assert new_handler.ref != handler.ref
    assert Process.alive?(new_handler.ref)
    IO.puts(">> Symbiont 重启成功 Old: #{inspect(handler.ref)} -> New: #{inspect(new_handler.ref)}")
  end
end
