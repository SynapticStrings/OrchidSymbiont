defmodule Orchid.Symbiont.Application do
  # 1. 这里 use Application
  use Application

  # 2. 这是系统调用的入口
  @impl true
  def start(_type, _args) do
    # 3. 这里才去启动你的 Runtime Supervisor
    Orchid.Symbiont.Runtime.start_link([])
  end
end
