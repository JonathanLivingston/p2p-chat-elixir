defmodule Weather do
  use GenServer
  alias Req

  # Client API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def refresh(city) do
    GenServer.call(__MODULE__, {:refresh, city})
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:refresh, city}, _from, state) do
    # Simulate fetching weather data for the city
    weather_data = fetch_weather_data(city)
    {:reply, weather_data, state}
  end

  defp fetch_weather_data(city) do
    cityData =
      Req.get("https://nominatim.openstreetmap.org/search?city=#{city}&format=json")
      |> case do
        {:ok, %{status: 200, body: body}} -> {:ok, body}
        {:ok, %{status: status}} -> {:error, "API returned #{status}"}
        {:error, reason} -> {:error, reason}
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
        %{
          city: city,
          temperature: "#{current["temperature"]} #{current_units["temperature"]}",
          cloud_cover: "#{current["cloud_cover"]} #{current_units["cloud_cover"]}",
          condition: case round(current["cloud_cover"]) do
            0 -> "Clear"
            v when v in 1..50 -> "Partly Cloudy"
            100 -> "Can't see any sun"
            _ -> "Cloudy"
          end
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
end
