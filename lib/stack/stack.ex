defmodule Stack do
  use GenServer

  # Client

  def start_link(default) when is_binary(default) do
    GenServer.start_link(__MODULE__, default, name: __MODULE__)
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def push(element) do
    GenServer.cast(__MODULE__, {:push, element})
  end

  def pop() do
    GenServer.call(__MODULE__, :pop)
  end

  def list() do
    GenServer.call(__MODULE__, :list)
  end

  # Server (callbacks)

  @impl true
  def init(elements) do
    case elements do
      [] -> {:ok, []}
      _ ->
        initial_state = String.split(elements, ",", trim: true)
        {:ok, initial_state}
    end
  end

  @impl true
  def handle_call(:pop, _from, state) do
    case state do
      [to_caller | new_state] ->
        {:reply, to_caller, new_state}
      [] ->
        {:reply, "no elements in stack", []}
    end
  end

  @impl true
  def handle_call(:list, _from, state) do
    Enum.each(state, &IO.puts/1)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:push, element}, state) do
    case state do
      [_ | _] ->
        new_state = [element | state]
        {:noreply, new_state}
      _ -> {:noreply, [element]}
    end

  end
end
