defmodule Chat.Server do
  @moduledoc """
  A GenServer that manages connected peers and message routing.

  ## What is a GenServer?
  GenServer (Generic Server) is an abstraction over an Erlang process that:
  - Holds state (here: the list of connected peer nodes)
  - Handles messages from other processes via callbacks
  - Runs concurrently with everything else in the system

  Two kinds of messages:
  - `call`  → synchronous, caller waits for a reply
  - `cast`  → asynchronous, fire-and-forget
  """

  use GenServer

  # ---------------------------------------------------------------------------
  # Client API — called from other modules or the CLI
  # ---------------------------------------------------------------------------

  def start_link(_opts) do
    # Registers the process under the module name so any code can reach it
    # with GenServer.call(Chat.Server, ...) instead of needing the PID.
    GenServer.start_link(__MODULE__, %{peers: []}, name: __MODULE__)
  end

  @doc "Connect to a remote node by atom name, e.g. :bob@myhostname"
  def connect(node_name) do
    GenServer.call(__MODULE__, {:connect, node_name})
  end

  @doc "Send a text message to all connected peers."
  def send_message(text) do
    GenServer.cast(__MODULE__, {:send_message, text})
  end

  @doc "Return the list of connected peer nodes."
  def peers do
    GenServer.call(__MODULE__, :peers)
  end

  # ---------------------------------------------------------------------------
  # Server callbacks — only called by the GenServer machinery
  # ---------------------------------------------------------------------------

  @impl true
  def init(initial_state) do
    # Called once when the process starts. Must return {:ok, state}.
    {:ok, initial_state}
  end

  @impl true
  def handle_call({:connect, node_name}, _from, state) do
    # Node.connect/1 attempts to establish a distributed Erlang connection.
    # Returns true on success, false/ignored otherwise.
    case Node.connect(node_name) do
      true ->
        peers = Enum.uniq([node_name | state.peers])
        IO.puts("[system] Connected to #{node_name}")
        {:reply, :ok, %{state | peers: peers}}

      _ ->
        {:reply, {:error, :unreachable}, state}
    end
  end

  @impl true
  def handle_call(:peers, _from, state) do
    {:reply, state.peers, state}
  end

  @impl true
  def handle_cast({:send_message, text}, state) do
    # Send the message to every peer's Chat.Server process.
    # {Chat.Server, peer_node} is a "remote name" — Erlang will route it
    # over the distribution channel to that node automatically.
    Enum.each(state.peers, fn peer ->
      GenServer.cast({__MODULE__, peer}, {:incoming_message, text, Node.self()})
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:incoming_message, text, from_node}, state) do
    # \r moves to line start so the prompt gets overwritten cleanly.
    IO.puts("\r[#{from_node}] #{text}")
    {:noreply, state}
  end
end
