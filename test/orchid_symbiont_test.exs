defmodule Orchid.Symbiont.Test do
  use ExUnit.Case, async: false

  # 引入我们刚才写的 Naming 模块，方便在测试里查动态名字
  alias Orchid.Symbiont.Naming

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
      # Symbiont.call 内部自带了 pid，所以不需要改，依然可以跨 session 工作
      {:ok, result} = Orchid.Symbiont.call(handler, {:process, Orchid.Param.get_payload(params)})
      {:ok, Orchid.Param.new(:result, :any, result)}
    end
  end

  # ==========================================
  # 测试环境初始化
  # ==========================================
  setup context do
    # 1. 使用当前测试的名称生成独一无二的 session_id
    session_id = :"session_#{context.test}"

    # 2. 将专属的 Symbiont.Runtime 挂载到当前测试的监控树下
    # 测试结束后，ExUnit 会自动清理这棵树，不会残留进程
    start_supervised!({Orchid.Symbiont.Runtime, session_id: session_id})

    # 将 session_id 传递给具体的 test 块
    %{session_id: session_id}
  end

  # ==========================================
  # 测试用例
  # ==========================================

  test "complete flow: register -> resolve -> inject -> run", %{session_id: session_id} do
    # 1. 在指定的 session_id 中注册服务
    :ok = Orchid.Symbiont.register(session_id, :stable_diffusion, {MockWorker, []})

    # 2. 解析时也带上 session_id
    {:ok, handler} = Orchid.Symbiont.Resolver.resolve(session_id, :stable_diffusion)

    assert is_pid(handler.ref)
    assert Process.alive?(handler.ref)
    IO.puts(">> Symbiont activated PID: #{inspect(handler.ref)}")

    input_params = %{data: Orchid.Param.new(:data, :any, "input_img")}

    # 3. 最关键的一步：通过 Orchid 的 baggage 把 session_id 传给底层的 Injector Hook
    opts = [
      baggage: %{session_id: session_id}
    ]

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

    # 测试进程崩溃重启
    Process.exit(handler.ref, :kill)
    Process.sleep(10)

    {:ok, new_handler} = Orchid.Symbiont.Resolver.resolve(session_id, :stable_diffusion)

    assert new_handler.ref != handler.ref
    assert Process.alive?(new_handler.ref)
    IO.puts(">> Symbiont re-activated successfully\n\nOld: #{inspect(handler.ref)} -> New: #{inspect(new_handler.ref)}")
  end

  test "auto shutdown on idle (TTL)", %{session_id: session_id} do
    :ok = Orchid.Symbiont.register(session_id, :fast_worker, {MockWorker, [ttl: 100]})

    {:ok, handler} = Orchid.Symbiont.Resolver.resolve(session_id, :fast_worker)
    pid = handler.ref
    assert Process.alive?(pid)

    Orchid.Symbiont.call(handler, "keep_alive")
    Process.sleep(50)
    assert Process.alive?(pid)

    Orchid.Symbiont.call(handler, "keep_alive_again")
    Process.sleep(150)

    # 验证进程是否因 TTL 超时被关闭
    refute Process.alive?(pid)

    # 获取动态的 Registry 名字并断言
    dynamic_registry_name = Naming.registry(session_id)
    assert [] == Registry.lookup(dynamic_registry_name, :fast_worker)

    {:ok, new_handler} = Orchid.Symbiont.Resolver.resolve(session_id, :fast_worker)
    assert new_handler.ref != pid
  end

  # ==========================================
  # 【新增】核心测试：多租户/沙盒隔离测试
  # ==========================================
  test "sessions are completely isolated" do
    session_a = :project_a_session
    session_b = :project_b_session

    # 手动拉起两个完全隔离的引擎运行时
    start_supervised!(Supervisor.child_spec({Orchid.Symbiont.Runtime, session_id: session_a}, id: session_a))
    start_supervised!(Supervisor.child_spec({Orchid.Symbiont.Runtime, session_id: session_b}, id: session_b))

    # 1. 在 Session A 注册并启动一个 Worker
    :ok = Orchid.Symbiont.register(session_a, :shared_name_worker, {MockWorker, []})
    {:ok, handler_a} = Orchid.Symbiont.Resolver.resolve(session_a, :shared_name_worker)

    # 2. 验证 Session B 根本不知道有这个东西存在（因为图纸存在 A 的 Catalog 里）
    assert {:error, {:unknown_symbiont, :shared_name_worker}} ==
             Orchid.Symbiont.Resolver.resolve(session_b, :shared_name_worker)

    # 3. 在 Session B 也注册一个同名的 Worker，并启动它
    :ok = Orchid.Symbiont.register(session_b, :shared_name_worker, {MockWorker, []})
    {:ok, handler_b} = Orchid.Symbiont.Resolver.resolve(session_b, :shared_name_worker)

    # 4. 终极断言：它们虽然名字一样，但由于位于不同的 Session 树下，它们的 PID 绝对不同！
    assert handler_a.ref != handler_b.ref
    assert Process.alive?(handler_a.ref)
    assert Process.alive?(handler_b.ref)
  end
end
