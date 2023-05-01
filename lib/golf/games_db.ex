defmodule Golf.GamesDb do
  import Ecto.Query, warn: false
  import Golf.Games

  alias Golf.Repo
  alias Golf.Users.User
  alias Golf.Games.{Game, Player, Event, JoinRequest, ChatMessage}

  # pubsub

  def broadcast_game_created(game_id) do
    Phoenix.PubSub.broadcast(Golf.PubSub, "games", {:game_created, game_id})
  end

  def broadcast_player_joined(game_id, player) do
    Phoenix.PubSub.broadcast(Golf.PubSub, "game:#{game_id}", {:player_joined, player})
  end

  def broadcast_game_started(game_id) do
    game = get_game(game_id)
    Phoenix.PubSub.broadcast(Golf.PubSub, "game:#{game_id}", {:game_started, game})
  end

  def broadcast_game_event(game_id) do
    game = get_game(game_id)
    Phoenix.PubSub.broadcast(Golf.PubSub, "game:#{game_id}", {:game_event, game})
  end

  def broadcast_join_request(%JoinRequest{} = request) do
    Phoenix.PubSub.broadcast(
      Golf.PubSub,
      "game:#{request.game_id}",
      {:join_request, request}
    )
  end

  def broadcast_chat_message(message_id) do
    message = get_chat_message(message_id)
    Phoenix.PubSub.broadcast(Golf.PubSub, "game:#{message.game_id}", {:chat_message, message})
  end

  # db queries

  def players_query(game_id) do
    from p in Player,
      where: [game_id: ^game_id],
      order_by: p.turn,
      join: u in User,
      on: [id: p.user_id],
      select: %Player{p | username: u.username}
  end

  def player_query(game_id, user_id) do
    from p in Player, where: [game_id: ^game_id, user_id: ^user_id]
  end

  def get_player(game_id, user_id) do
    player_query(game_id, user_id)
    |> Repo.one()
  end

  def unconfirmed_join_requests_query(game_id) do
    from(jr in JoinRequest,
      where: [game_id: ^game_id, confirmed?: false],
      join: u in User,
      on: [id: jr.user_id],
      order_by: jr.inserted_at,
      select: %JoinRequest{jr | username: u.username}
    )
  end

  def get_unconfirmed_join_requests(game_id) do
    unconfirmed_join_requests_query(game_id)
    |> Repo.all()
  end

  def chat_messages_query(game_id) do
    from(cm in ChatMessage,
      where: [game_id: ^game_id],
      join: u in User,
      on: [id: cm.user_id],
      order_by: [desc: cm.inserted_at],
      select: %ChatMessage{cm | username: u.username}
    )
  end

  def get_game(game_id) do
    Repo.get(Game, game_id)
    |> Repo.preload(
      players: players_query(game_id),
      join_requests: unconfirmed_join_requests_query(game_id),
      chat_messages: chat_messages_query(game_id)
    )
  end

  def get_chat_message(message_id) do
    from(cm in ChatMessage,
      where: [id: ^message_id],
      join: u in User,
      on: [id: cm.user_id],
      select: %ChatMessage{cm | username: u.username}
    )
    |> Repo.one()
  end

  # db updates

  def create_game(%User{} = user) do
    deck = new_deck(decks_to_use()) |> Enum.shuffle()

    {:ok, %{game: game} = multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:game, %Game{status: :init, deck: deck, turn: 0})
      |> Ecto.Multi.insert(:player, fn %{game: game} ->
        Ecto.build_assoc(game, :players, %{user_id: user.id, turn: 0, host?: true})
      end)
      |> Repo.transaction()

    broadcast_game_created(game.id)
    {:ok, multi}
  end

  def make_join_request(%JoinRequest{} = join_request) do
    {:ok, join_request} = Repo.insert(join_request)
    broadcast_join_request(join_request)
    {:ok, join_request}
  end

  def confirm_join_request(%Game{} = game, %JoinRequest{} = request) do
    player_turn = length(game.players)

    {:ok, %{player: player} = multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(
        :player,
        Ecto.build_assoc(game, :players, %{user_id: request.user_id, turn: player_turn})
      )
      |> Ecto.Multi.update(:join_request, JoinRequest.changeset(request, %{confirmed?: true}))
      |> Repo.transaction()

    broadcast_player_joined(game.id, player)
    {:ok, multi}
  end

  def insert_chat_message(%ChatMessage{} = message) do
    {:ok, message} = Repo.insert(message)
    broadcast_chat_message(message.id)
    {:ok, message}
  end

  defp update_player_hands(multi, players, hands) do
    changesets =
      Enum.zip(players, hands)
      |> Enum.map(fn {player, hand} -> Player.changeset(player, %{hand: hand}) end)

    Enum.reduce(changesets, multi, fn cs, multi ->
      Ecto.Multi.update(multi, {:player, cs.data.id}, cs)
    end)
  end

  def start_game(%Game{status: :init} = game) do
    num_cards_to_deal = hand_size() * length(game.players)
    {cards, deck} = Enum.split(game.deck, num_cards_to_deal)

    {:ok, card, deck} = deal_from_deck(deck)
    table_cards = [card | game.table_cards]

    hands =
      cards
      |> Enum.map(fn name -> %{"name" => name, "face_up?" => false} end)
      |> Enum.chunk_every(hand_size())

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.update(
        :game,
        Game.changeset(game, %{status: :flip2, deck: deck, table_cards: table_cards})
      )
      |> update_player_hands(game.players, hands)
      |> Repo.transaction()

    broadcast_game_started(game.id)
    {:ok, multi}
  end

  defp replace_player(players, player) do
    Enum.map(
      players,
      fn p -> if p.id == player.id, do: player, else: p end
    )
  end

  def handle_game_event(
        %Game{status: :flip2} = game,
        %Player{} = player,
        %Event{action: :flip} = event
      ) do
    if num_cards_face_up(player.hand) < 2 do
      hand = flip_card(player.hand, event.hand_index)

      {:ok, multi} =
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:event, event)
        |> Ecto.Multi.update(:player, Player.changeset(player, %{hand: hand}))
        |> Ecto.Multi.update(:game, fn %{player: player} ->
          players = replace_player(game.players, player)
          status = if all_two_face_up?(players), do: :take, else: :flip2
          Game.changeset(game, %{status: status})
        end)
        |> Repo.transaction()

      broadcast_game_event(game.id)
      {:ok, multi}
    else
      {:error, :already_flipped_two}
    end
  end

  def handle_game_event(
        %Game{status: :flip} = game,
        %Player{} = player,
        %Event{action: :flip} = event
      ) do
    hand = flip_card(player.hand, event.hand_index)

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:event, event)
      |> Ecto.Multi.update(:player, Player.changeset(player, %{hand: hand}))
      |> Ecto.Multi.update(:game, fn %{player: player} ->
        players = replace_player(game.players, player)

        {status, turn} =
          cond do
            all_players_all_face_up?(players) ->
              {:over, game.turn}

            all_face_up?(player.hand) ->
              {:last_take, game.turn + 1}

            true ->
              {:take, game.turn + 1}
          end

        Game.changeset(game, %{status: status, turn: turn})
      end)
      |> Repo.transaction()

    broadcast_game_event(game.id)
    {:ok, multi}
  end

  def handle_game_event(
        %Game{status: :take} = game,
        %Player{} = player,
        %Event{action: :take_from_deck} = event
      ) do
    {:ok, card, deck} = deal_from_deck(game.deck)

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:event, event)
      |> Ecto.Multi.update(:player, Player.changeset(player, %{held_card: card}))
      |> Ecto.Multi.update(:game, Game.changeset(game, %{status: :hold, deck: deck}))
      |> Repo.transaction()

    broadcast_game_event(game.id)
    {:ok, multi}
  end

  def handle_game_event(
        %Game{status: :last_take} = game,
        %Player{} = player,
        %Event{action: :take_from_deck} = event
      ) do
    {:ok, card, deck} = deal_from_deck(game.deck)

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:event, event)
      |> Ecto.Multi.update(:player, Player.changeset(player, %{held_card: card}))
      |> Ecto.Multi.update(:game, Game.changeset(game, %{status: :last_hold, deck: deck}))
      |> Repo.transaction()

    broadcast_game_event(game.id)
    {:ok, multi}
  end

  def handle_game_event(
        %Game{status: :take} = game,
        %Player{} = player,
        %Event{action: :take_from_table} = event
      ) do
    [card | table_cards] = game.table_cards

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:event, event)
      |> Ecto.Multi.update(:player, Player.changeset(player, %{held_card: card}))
      |> Ecto.Multi.update(
        :game,
        Game.changeset(game, %{status: :hold, table_cards: table_cards})
      )
      |> Repo.transaction()

    broadcast_game_event(game.id)
    {:ok, multi}
  end

  def handle_game_event(
        %Game{status: :last_take} = game,
        %Player{} = player,
        %Event{action: :take_from_table} = event
      ) do
    [card | table_cards] = game.table_cards

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:event, event)
      |> Ecto.Multi.update(:player, Player.changeset(player, %{held_card: card}))
      |> Ecto.Multi.update(
        :game,
        Game.changeset(game, %{status: :last_hold, table_cards: table_cards})
      )
      |> Repo.transaction()

    broadcast_game_event(game.id)
    {:ok, multi}
  end

  def handle_game_event(
        %Game{status: :hold} = game,
        %Player{} = player,
        %Event{action: :discard} = event
      )
      when is_struct(player) do
    card = player.held_card
    table_cards = [card | game.table_cards]

    {status, turn} =
      if one_face_down?(player.hand) do
        {:take, game.turn + 1}
      else
        {:flip, game.turn}
      end

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:event, event)
      |> Ecto.Multi.update(:player, Player.changeset(player, %{held_card: nil}))
      |> Ecto.Multi.update(
        :game,
        Game.changeset(game, %{status: status, table_cards: table_cards, turn: turn})
      )
      |> Repo.transaction()

    broadcast_game_event(game.id)
    {:ok, multi}
  end

  def handle_game_event(
        %Game{status: :last_hold} = game,
        %Player{} = player,
        %Event{action: :discard} = event
      ) do
    card = player.held_card
    table_cards = [card | game.table_cards]
    other_players = Enum.reject(game.players, fn p -> p.id == player.id end)

    {status, turn, hand} =
      if all_players_all_face_up?(other_players) do
        {:over, game.turn, flip_all(player.hand)}
      else
        {:last_take, game.turn + 1, player.hand}
      end

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:event, event)
      |> Ecto.Multi.update(:player, Player.changeset(player, %{held_card: nil, hand: hand}))
      |> Ecto.Multi.update(
        :game,
        Game.changeset(game, %{status: status, table_cards: table_cards, turn: turn})
      )
      |> Repo.transaction()

    broadcast_game_event(game.id)
    {:ok, multi}
  end

  def handle_game_event(
        %Game{status: :hold} = game,
        %Player{} = player,
        %Event{action: :swap} = event
      ) do
    {card, hand} = swap_card(player.hand, player.held_card, event.hand_index)
    table_cards = [card | game.table_cards]

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:event, event)
      |> Ecto.Multi.update(:player, Player.changeset(player, %{hand: hand, held_card: nil}))
      |> Ecto.Multi.update(:game, fn %{player: player} ->
        players = replace_player(game.players, player)

        {status, turn} =
          cond do
            all_players_all_face_up?(players) ->
              {:over, game.turn}

            all_face_up?(player.hand) ->
              {:last_take, game.turn + 1}

            true ->
              {:take, game.turn + 1}
          end

        Game.changeset(game, %{status: status, table_cards: table_cards, turn: turn})
      end)
      |> Repo.transaction()

    broadcast_game_event(game.id)
    {:ok, multi}
  end
end

# def game_exists?(game_id) do
#   from(g in Game, where: [id: ^game_id])
#   |> Repo.exists?()
# end

# def last_event_query(game_id) do
#   from e in Event,
#     where: [game_id: ^game_id],
#     order_by: [desc: e.inserted_at],
#     limit: 1
# end
