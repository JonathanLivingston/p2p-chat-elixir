defmodule Chat.CLI do
  @moduledoc """
  Interactive command-line loop for the chat application.

  Start it from the IEx shell with: Chat.CLI.run()

  Available commands:
    /connect <name>          Connect to another node on the same machine
    /connect <name@host>     Connect to a node on a different machine
    /peers                   List connected peers
    /help                    Show this help
    /quit                    Exit the application
    <anything else>          Send as a chat message
  """

  def run do
    my_node = Node.self()

    IO.puts("""

    ╔══════════════════════════════╗
    ║       Elixir P2P Chat        ║
    ╚══════════════════════════════╝
    Your node : #{my_node}
    Commands  : /connect <name>, /peers, /help, /quit
    """)

    # The node name "alice@host" → short name "alice" used as the prompt.
    short_name = my_node |> to_string() |> String.split("@") |> hd()
    loop(short_name)
  end

  # ---------------------------------------------------------------------------
  # Private — the loop and command handlers
  # ---------------------------------------------------------------------------

  defp loop(prompt) do
    # IO.gets/1 blocks until the user presses Enter, then returns the line.
    case IO.gets("#{prompt}> ") do
      :eof -> IO.puts("[system] stdin closed, exiting."); System.stop(0)
      {:error, reason} -> IO.puts("[system] IO error: #{reason}"); System.stop(1)
      line -> line |> String.trim() |> dispatch(); loop(prompt)
    end
  end

  # Pattern matching on the input string — a core Elixir feature.
  # Elixir tries each clause top-to-bottom and picks the first that matches.
  defp dispatch(""), do: :ok

  defp dispatch("/quit") do
    IO.puts("[system] Goodbye.")
    System.stop(0)
  end

  defp dispatch("/help") do
    IO.puts("""
    Commands:
      /connect <name>       Connect to node on this machine (e.g. /connect bob)
      /connect <name@host>  Connect to node on another machine
      /peers                List connected peers
      /quit                 Exit
      <message>             Send message to all peers
    """)
  end

  defp dispatch("/peers") do
    case Chat.Server.peers() do
      [] -> IO.puts("[system] No connected peers yet.")
      peers -> IO.puts("[system] Peers: #{Enum.join(peers, ", ")}")
    end
  end

  defp dispatch("/connect " <> name_str) do
    node_name = resolve_node_name(String.trim(name_str))

    IO.puts("[system] Connecting to #{node_name}...")

    case Chat.Server.connect(node_name) do
      :ok -> :ok  # success message printed by the server
      {:error, :unreachable} ->
        IO.puts("[system] Could not reach #{node_name}. Make sure the other node is running.")
    end
  end

  defp dispatch("/" <> unknown) do
    IO.puts("[system] Unknown command: /#{unknown}. Type /help for available commands.")
  end

  defp dispatch(text) do
    if Chat.Server.peers() == [] do
      IO.puts("[system] Not connected to anyone. Use /connect <name> first.")
    else
      Chat.Server.send_message(text)
    end
  end

  # If the user types just "bob" (no @host), append our own host automatically.
  # This makes same-machine testing much easier.
  defp resolve_node_name(name_str) do
    if String.contains?(name_str, "@") do
      String.to_atom(name_str)
    else
      [_self, host] = Node.self() |> to_string() |> String.split("@")
      String.to_atom("#{name_str}@#{host}")
    end
  end
end
