defmodule GolfWeb.GamesLive do
  use GolfWeb, :live_view
  alias Golf.GamesDb

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]

    if connected?(socket) do
      send(self(), :load_games)
    end

    {:ok,
     assign(socket,
      user_id: user_id,
      games: [])}
  end

  @impl true
  def handle_info(:load_games, socket) do
    user_id = socket.assigns.user_id
    games =
      GamesDb.get_user_games(user_id)
      |> Enum.map(fn g -> Map.update!(g, :inserted_at, &format_datetime/1) end)

    {:noreply, assign(socket, games: games)}
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %H:%S")
  end
end
