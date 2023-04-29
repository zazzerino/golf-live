defmodule GolfWeb.GameLive do
  use GolfWeb, :live_view
  alias Golf.GamesDb

  @impl true
  def mount(%{"game_id" => game_id}, _session, socket) do
    with {game_id, _} <- Integer.parse(game_id),
         true <- GamesDb.game_exists?(game_id) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Golf.PubSub, "game:#{game_id}")
        send(self(), {:load_game, game_id})
      end

      {:ok,
       assign(socket,
         page_title: "Game #{game_id}",
         game_id: game_id
       )}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Game #{game_id} not found.")
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_info({:load_game, game_id}, socket) do
    game = GamesDb.get_game(game_id)
    {:noreply, assign_game_data(socket, game)}
  end

  defp assign_game_data(socket, game) do
    assign(socket,
      game: game
    )
  end
end
