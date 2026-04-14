defmodule Weather do
  use GenServer
  require Logger
  alias Req

  @poll_interval :timer.seconds(30)

  defstruct location_cache: %{},
            weather_data: %{}

  # Client API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def refresh(city) do
    GenServer.call(__MODULE__, {:refresh, city})
  end

  def refresh_async(city) do
    GenServer.cast(__MODULE__, {:refresh_async, city})
  end

  @impl true
  def init(_) do
    schedule_poll()
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_info(:poll_weather, state) do
    Enum.each(Map.keys(state.weather_data), fn city ->
      GenServer.cast(self(), {:refresh_async, city})
    end)

    schedule_poll()

    {:noreply, state}
  end

  @impl true
  def handle_info({_ref, {:ok, %Weather{} = updated_state}}, _) do
    # Do something with the new data, like updating state
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({_ref, {:ok, data, _status}}, state) do
    {:noreply, update_data(state, data)}
  end

  @impl true
  def handle_info({_ref, {:error, error_msg, _status}}, state) do
    Logger.error("Error fetching weather data: #{error_msg}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _status}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:refresh_async, city}, state) do
    Task.Supervisor.async_nolink(Weather.TaskSupervisor, fn ->
      fetched_data = fetch_weather_data(city, state)

      case fetched_data do
        {cache, weather} -> {:ok, update_data(state, {cache, weather})}
        %{error: reason} -> {:error, reason}
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_call({:refresh, city}, _from, state) do
    data = fetch_weather_data(city, state)

    case data do
      {cache, weather} -> {:reply, weather, update_data(state, {cache, weather})}
      %{error: reason} -> {:reply, reason, state}
    end
  end

  defp fetch_weather_data(city, state) do
    cityData =
      case Map.get(state.location_cache, city) do
        %{} = cache ->
          {:ok, [cache]}

        nil ->
          Req.get("https://nominatim.openstreetmap.org/search?city=#{city}&format=json")
          |> case do
            {:ok, %{status: 200, body: body}} -> {:ok, body}
            {:ok, %{status: status}} -> {:error, "API returned #{status}"}
            {:error, reason} -> {:error, reason}
          end
      end

    cityWeather =
      case cityData do
        {:ok, [%{"lat" => lat, "lon" => lon} | _]} ->
          fetch_city_weather_open_meteo(lat, lon)

        {:ok, []} ->
          {:error, "City not found"}

        {:error, reason} ->
          {:error, reason}
      end

    case cityWeather do
      {:ok, [%{"current" => current, "current_units" => current_units} | _]} ->
        {
          %{
            city => %{
              "lat" => elem(cityData, 1) |> hd |> Map.get("lat"),
              "lon" => elem(cityData, 1) |> hd |> Map.get("lon")
            }
          },
          %{
            city => %{
              temperature: "#{current["temperature"]} #{current_units["temperature"]}",
              cloud_cover: "#{current["cloud_cover"]} #{current_units["cloud_cover"]}",
              condition:
                case round(current["cloud_cover"]) do
                  0 -> "Clear"
                  v when v in 1..50 -> "Partly Cloudy"
                  100 -> "Can't see any sun"
                  _ -> "Cloudy"
                end
            }
          }
        }

      {:error, reason} ->
        %{error: reason}
    end
  end

  defp fetch_city_weather_open_meteo(lat, lon) do
    case Req.get(
           "https://api.open-meteo.com/v1/forecast?latitude=#{lat}&longitude=#{lon}&current=temperature,cloud_cover",
           params: [latitude: lat, longitude: lon]
         ) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, "API returned #{status}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp schedule_poll do
    Process.send_after(self(), :poll_weather, @poll_interval)
  end

  defp update_data(state, updated) do
    cache = elem(updated, 0)
    weather = elem(updated, 1)

    state = update_in(state.weather_data, fn current -> Map.merge(current, weather) end)
    state = update_in(state.location_cache, fn current -> Map.merge(current, cache) end)

    state
  end
end
