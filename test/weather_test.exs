defmodule WeatherTest do
  use ExUnit.Case, async: true

  # Start an isolated Weather GenServer for each test.
  # Weather.TaskSupervisor must exist for refresh_async; we start one per test.
  setup do
    sup_name = :"weather_task_sup_#{:erlang.unique_integer([:positive])}"
    {:ok, _} = Task.Supervisor.start_link(name: sup_name)
    {:ok, pid} = GenServer.start_link(Weather, %{})
    {:ok, pid: pid, sup: sup_name}
  end

  describe "init" do
    test "starts with empty state", %{pid: pid} do
      assert :sys.get_state(pid) == %{}
    end
  end

  describe "handle_info — task results" do
    test "stores successful weather data keyed by city", %{pid: pid} do
      data = %{city: "Berlin", temperature: "12 °C", cloud_cover: "50 %", condition: "Partly Cloudy"}
      send(pid, {make_ref(), {:ok, data, :ignored}})
      # A subsequent call flushes the mailbox
      :sys.get_state(pid)
      assert :sys.get_state(pid) == %{"Berlin" => data}
    end

    test "does not change state on task error", %{pid: pid} do
      send(pid, {make_ref(), {:error, "timeout", :ignored}})
      :sys.get_state(pid)
      assert :sys.get_state(pid) == %{}
    end

    test "ignores :DOWN messages from monitored tasks", %{pid: pid} do
      send(pid, {:DOWN, make_ref(), :process, self(), :normal})
      :sys.get_state(pid)
      assert :sys.get_state(pid) == %{}
    end

    test "accumulates weather data for multiple cities", %{pid: pid} do
      berlin = %{city: "Berlin", temperature: "12 °C", cloud_cover: "20 %", condition: "Partly Cloudy"}
      london = %{city: "London", temperature: "8 °C", cloud_cover: "90 %", condition: "Cloudy"}
      send(pid, {make_ref(), {:ok, berlin, :ignored}})
      send(pid, {make_ref(), {:ok, london, :ignored}})
      :sys.get_state(pid)
      state = :sys.get_state(pid)
      assert Map.has_key?(state, "Berlin")
      assert Map.has_key?(state, "London")
    end

    test "overwrites stale city data with new result", %{pid: pid} do
      old = %{city: "Paris", temperature: "5 °C", cloud_cover: "100 %", condition: "Can't see any sun"}
      new = %{city: "Paris", temperature: "15 °C", cloud_cover: "0 %", condition: "Clear"}
      send(pid, {make_ref(), {:ok, old, :ignored}})
      send(pid, {make_ref(), {:ok, new, :ignored}})
      :sys.get_state(pid)
      assert :sys.get_state(pid)["Paris"].temperature == "15 °C"
    end
  end

  describe "refresh/1 — live API" do
    @describetag :integration
    test "returns a map with city, temperature, cloud_cover, condition for a valid city" do
      result = Weather.refresh("London")
      assert is_map(result)
      assert Map.has_key?(result, :city)
      assert Map.has_key?(result, :temperature)
      assert Map.has_key?(result, :cloud_cover)
      assert Map.has_key?(result, :condition)
      assert result.city == "London"
      assert result.condition in ["Clear", "Partly Cloudy", "Cloudy", "Can't see any sun"]
    end

    test "returns error map for unknown city" do
      result = Weather.refresh("__nonexistent_city_xyz__")
      assert Map.has_key?(result, :error)
    end
  end
end
