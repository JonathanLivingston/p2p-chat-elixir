defmodule StackTest do
  use ExUnit.Case, async: true

  # Start a fresh isolated Stack process per test to avoid global name conflicts.
  setup do
    {:ok, pid} = GenServer.start_link(Stack, [])
    {:ok, pid: pid}
  end

  describe "init" do
    test "starts with empty list" do
      {:ok, pid} = GenServer.start_link(Stack, [])
      assert GenServer.call(pid, :pop) == "no elements in stack"
    end

    test "parses comma-separated string into initial elements" do
      {:ok, pid} = GenServer.start_link(Stack, "a,b,c")
      assert GenServer.call(pid, :pop) == "a"
      assert GenServer.call(pid, :pop) == "b"
      assert GenServer.call(pid, :pop) == "c"
    end

    test "trims empty segments from init string" do
      {:ok, pid} = GenServer.start_link(Stack, "")
      assert GenServer.call(pid, :pop) == "no elements in stack"
    end
  end

  describe "push and pop" do
    test "push then pop returns the element", %{pid: pid} do
      GenServer.cast(pid, {:push, "hello"})
      assert GenServer.call(pid, :pop) == "hello"
    end

    test "pop on empty stack returns message", %{pid: pid} do
      assert GenServer.call(pid, :pop) == "no elements in stack"
    end

    test "push multiple elements, pop returns LIFO order", %{pid: pid} do
      GenServer.cast(pid, {:push, "first"})
      GenServer.cast(pid, {:push, "second"})
      GenServer.cast(pid, {:push, "third"})
      assert GenServer.call(pid, :pop) == "third"
      assert GenServer.call(pid, :pop) == "second"
      assert GenServer.call(pid, :pop) == "first"
    end

    test "pop after exhausting all elements returns empty message", %{pid: pid} do
      GenServer.cast(pid, {:push, "only"})
      GenServer.call(pid, :pop)
      assert GenServer.call(pid, :pop) == "no elements in stack"
    end

    test "push onto empty stack works", %{pid: pid} do
      # Covers the `_ -> {:noreply, [element]}` branch in handle_cast
      GenServer.call(pid, :pop)  # ensure empty
      GenServer.cast(pid, {:push, "fresh"})
      assert GenServer.call(pid, :pop) == "fresh"
    end
  end

  describe "list" do
    test "list returns :ok", %{pid: pid} do
      GenServer.cast(pid, {:push, "x"})
      assert GenServer.call(pid, :list) == :ok
    end
  end
end
