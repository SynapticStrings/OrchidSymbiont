defmodule OrchidSymbiont.Catalog do
  use Agent

  def start_link(session_id: session_id) do
    name = OrchidSymbiont.Naming.catalog(session_id)
    Agent.start_link(fn -> %{} end, name: name)
  end

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def lookup(name \\ __MODULE__, key) do
    case Agent.get(name, &Map.get(&1, key)) do
      nil -> :not_found
      val -> {:ok, val}
    end
  end

  def register(name \\ __MODULE__, key, value) do
    Agent.update(name, &Map.put(&1, key, value))
  end

  def dump(name \\ __MODULE__), do: Agent.get(name, & &1)
  def restore(name \\ __MODULE__, data), do: Agent.update(name, fn _ -> data end)
end
