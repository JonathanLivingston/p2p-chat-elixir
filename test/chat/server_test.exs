defmodule Chat.ServerTest do
  use ExUnit.Case, async: true

  # Start a fresh, unnamed Chat.Server for each test.
  # The global Chat.Server registered by the Application is separate and unaffected.
  setup do
    {:ok, pid} = GenServer.start_link(Chat.Server, %{peers: [], messages: []})
    {:ok, pid: pid}
  end

  describe "initial state" do
    test "no peers on start", %{pid: pid} do
      assert GenServer.call(pid, :peers) == []
    end

    test "empty history on start", %{pid: pid} do
      assert GenServer.call(pid, :history) == []
    end
  end

  describe "connect" do
    test "returns error for unreachable node", %{pid: pid} do
      assert GenServer.call(pid, {:connect, :nonexistent@nowhere}) == {:error, :unreachable}
    end

    test "state is unchanged after failed connect", %{pid: pid} do
      GenServer.call(pid, {:connect, :nonexistent@nowhere})
      assert GenServer.call(pid, :peers) == []
    end
  end

  describe "add_peer" do
    test "adds a peer to the list", %{pid: pid} do
      GenServer.cast(pid, {:add_peer, :bob@localhost})
      assert GenServer.call(pid, :peers) == [:bob@localhost]
    end

    test "deduplicates peers", %{pid: pid} do
      GenServer.cast(pid, {:add_peer, :bob@localhost})
      GenServer.cast(pid, {:add_peer, :bob@localhost})
      assert GenServer.call(pid, :peers) == [:bob@localhost]
    end

    test "multiple distinct peers are all stored", %{pid: pid} do
      GenServer.cast(pid, {:add_peer, :alice@localhost})
      GenServer.cast(pid, {:add_peer, :bob@localhost})
      peers = GenServer.call(pid, :peers)
      assert :alice@localhost in peers
      assert :bob@localhost in peers
      assert length(peers) == 2
    end
  end

  describe "send_message" do
    test "adds message to history with current node as sender", %{pid: pid} do
      GenServer.cast(pid, {:send_message, "hello world"})
      [{from, text, timestamp}] = GenServer.call(pid, :history)
      assert from == Node.self()
      assert text == "hello world"
      assert %DateTime{} = timestamp
    end

    test "appends multiple messages in order", %{pid: pid} do
      GenServer.cast(pid, {:send_message, "first"})
      GenServer.cast(pid, {:send_message, "second"})
      history = GenServer.call(pid, :history)
      assert length(history) == 2
      {_, text1, _} = Enum.at(history, 0)
      {_, text2, _} = Enum.at(history, 1)
      assert text1 == "first"
      assert text2 == "second"
    end

    test "send_message with no peers still records in history", %{pid: pid} do
      GenServer.cast(pid, {:send_message, "lonely message"})
      [{_, text, _}] = GenServer.call(pid, :history)
      assert text == "lonely message"
    end
  end

  describe "incoming_message" do
    test "stores incoming message in history", %{pid: pid} do
      GenServer.cast(pid, {:incoming_message, "hi there", :alice@remote})
      [{from, text, timestamp}] = GenServer.call(pid, :history)
      assert from == :alice@remote
      assert text == "hi there"
      assert %DateTime{} = timestamp
    end

    test "incoming and outgoing messages accumulate together", %{pid: pid} do
      GenServer.cast(pid, {:send_message, "outgoing"})
      GenServer.cast(pid, {:incoming_message, "incoming", :alice@remote})
      history = GenServer.call(pid, :history)
      assert length(history) == 2
    end
  end
end
