defmodule GolfWeb.GameLive do
  use GolfWeb, :live_view
  import GolfWeb.GameComponents
  alias Golf.{Games, GamesDb}

  @impl true
  def mount(%{"game_id" => game_id}, session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Golf.PubSub, "game:#{game_id}")
      send(self(), {:load_game, game_id})
    end

    {:ok,
     assign(socket,
       page_title: "Game #{game_id}",
       user_id: session["user_id"],
       game_id: game_id,
       game_status: nil,
       table_cards: [],
       player: nil,
       deck_playable?: nil,
       table_playable?: nil,
       can_start_game?: nil
     )}
  end

  @impl true
  def handle_info({:load_game, game_id}, socket) do
    case GamesDb.get_game(game_id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Game #{game_id} not found.")
         |> redirect(to: ~p"/")}

      game ->
        {:noreply, assign_game_data(socket, game)}
    end
  end

  @impl true
  def handle_info({:game_started, game}, socket) do
    {:noreply, assign_game_data(socket, game)}
  end

  @impl true
  def handle_info(info, socket) do
    IO.inspect(info, label: "INFO")
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_game", _, %{assigns: %{can_start_game?: true, game: game}} = socket) do
    GamesDb.start_game(game)
    {:noreply, socket}
  end

  @impl true
  def handle_event(name, value, socket) do
    IO.inspect(name, label: "EVENT NAME")
    IO.inspect(value, label: "EVENT VALUE")
    {:noreply, socket}
  end

  defp assign_game_data(socket, game) do
    user_id = socket.assigns.user_id
    player = GamesDb.get_player(game.id, user_id)
    can_start_game? = player && player.host? && game.status == :init

    playable_cards =
      if player do
        Games.playable_cards(game, player)
      else
        []
      end

    assign(socket,
      game: game,
      game_status: game.status,
      table_cards: game.table_cards,
      player: player,
      can_start_game?: can_start_game?,
      deck_playable?: :deck in playable_cards,
      table_playable?: :table in playable_cards
    )
  end
end
