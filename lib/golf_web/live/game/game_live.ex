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
       table_card_0: nil,
       table_card_1: nil,
       player: nil,
       players: [],
       deck_playable?: nil,
       table_playable?: nil,
       playable_cards: [],
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

    player_index = player && Enum.find_index(game.players, &(&1.id == player.id))
    positions = Games.hand_positions(length(game.players))

    players =
      game.players
      |> maybe_rotate(player_index)
      |> assign_positions_and_scores(positions)

    assign(socket,
      game: game,
      game_status: game.status,
      table_card_0: Enum.at(game.table_cards, 0),
      table_card_1: Enum.at(game.table_cards, 1),
      player: player,
      players: players,
      can_start_game?: can_start_game?,
      deck_playable?: :deck in playable_cards,
      table_playable?: :table in playable_cards,
      playable_cards: playable_cards
    )
  end

  defp assign_positions_and_scores(players, positions) do
    Enum.zip_with(players, positions, fn player, position ->
      player
      |> Map.put(:position, position)
      |> Map.put(:score, Games.score(player.hand))
    end)
  end

  defp maybe_rotate(players, nil), do: players
  defp maybe_rotate(players, index), do: rotate(players, index)

  defp rotate(list, 0), do: list

  defp rotate(list, n) do
    list
    |> Stream.cycle()
    |> Stream.drop(n)
    |> Stream.take(length(list))
    |> Enum.to_list()
  end
end
