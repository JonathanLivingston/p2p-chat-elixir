defmodule ChatTest do
  use ExUnit.Case, async: true

  test "application supervisor is running" do
    assert Process.whereis(Chat.Supervisor) != nil
  end

  test "Chat.Server is registered and running" do
    assert Process.whereis(Chat.Server) != nil
  end

  test "Stack is registered and running" do
    assert Process.whereis(Stack) != nil
  end

  test "Weather is registered and running" do
    assert Process.whereis(Weather) != nil
  end

  test "Weather.TaskSupervisor is registered and running" do
    assert Process.whereis(Weather.TaskSupervisor) != nil
  end
end
