defmodule GolfWeb.GameLive do
  use GolfWeb, :live_view
  import GolfWeb.GameComponents
  alias Golf.{Games, GamesDb}
  alias Golf.Games.Event

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
       playable_cards: [],
       deck_playable?: nil,
       table_playable?: nil,
       held_playable?: nil,
       can_start_game?: nil,
       can_join_game?: nil
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
  def handle_info({:game_event, game}, socket) do
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
  def handle_event("hand_click", value, %{assigns: %{player: user_player, game: game}} = socket)
      when is_struct(user_player) do
    with player_id <- String.to_integer(value["player-id"]),
         index <- String.to_integer(value["index"]),
         card <- String.to_existing_atom("hand_#{index}"),
         true <- user_player.id == player_id,
         true <- card in socket.assigns.playable_cards,
         event <- hand_click_event(game, user_player, index),
         {:ok, _} <- GamesDb.handle_game_event(game, user_player, event) do
      {:noreply, socket}
    else
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("deck_click", %{"playable" => _}, socket) do
    game = socket.assigns.game
    player = socket.assigns.player
    event = Event.take_from_deck(game.id, player.id)
    {:ok, _} = GamesDb.handle_game_event(game, player, event)
    {:noreply, socket}
  end

  @impl true
  def handle_event("table_click", %{"playable" => _}, socket) do
    game = socket.assigns.game
    player = socket.assigns.player
    event = Event.take_from_table(game.id, player.id)
    {:ok, _} = GamesDb.handle_game_event(game, player, event)
    {:noreply, socket}
  end

  @impl true
  def handle_event("held_click", %{"playable" => _}, socket) do
    game = socket.assigns.game
    player = socket.assigns.player
    event = Event.discard(game.id, player.id)
    {:ok, _} = GamesDb.handle_game_event(game, player, event)
    {:noreply, socket}
  end

  @impl true
  def handle_event(_, _, socket) do
    {:noreply, socket}
  end

  defp hand_click_event(game, player, index) do
    action =
      case game.status do
        s when s in [:flip2, :flip] ->
          :flip

        :hold ->
          :swap
      end

    %Event{game_id: game.id, player_id: player.id, action: action, hand_index: index}
  end

  defp assign_game_data(%{assigns: %{user_id: user_id}} = socket, game) do
    player_index = Enum.find_index(game.players, &(&1.user_id == user_id))
    player = player_index && Enum.at(game.players, player_index)
    positions = Games.hand_positions(length(game.players))

    playable_cards =
      if player do
        Games.playable_cards(game, player)
      else
        []
      end

    players =
      game.players
      |> maybe_rotate(player_index)
      |> assign_positions_and_scores(positions)

    can_start_game? = player && player.host? && game.status == :init
    can_join_game? = !player && game.status == :init

    assign(socket,
      game: game,
      game_status: game.status,
      table_card_0: Enum.at(game.table_cards, 0),
      table_card_1: Enum.at(game.table_cards, 1),
      player: player,
      players: players,
      playable_cards: playable_cards,
      deck_playable?: :deck in playable_cards,
      table_playable?: :table in playable_cards,
      held_playable?: :held in playable_cards,
      can_start_game?: can_start_game?,
      can_join_game?: can_join_game?
    )
  end

  defp assign_positions_and_scores(players, positions) do
    Enum.zip_with(players, positions, fn player, position ->
      player
      |> Map.put(:position, position)
      |> Map.put(:score, Games.score(player.hand))
    end)
  end

  defp maybe_rotate(list, nil), do: list
  defp maybe_rotate(list, 0), do: list
  defp maybe_rotate(list, n) do
    list
    |> Stream.cycle()
    |> Stream.drop(n)
    |> Stream.take(length(list))
    |> Enum.to_list()
  end
end
