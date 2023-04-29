defmodule Golf.GamesDb do
  import Ecto.Query, warn: false
  import Golf.Games

  alias Golf.{Repo, User}
  alias Golf.Games.{Game, Player, Event}

  # pubsub

  def broadcast_game_created(game_id) do
    Phoenix.PubSub.broadcast(Golf.PubSub, "games", {:game_created, game_id})
  end

  def broadcast_player_added(game_id, player) do
    Phoenix.PubSub.broadcast(Golf.PubSub, "game:#{game_id}", {:player_added, player})
  end

  def broadcast_game_started(game_id) do
    game = get_game(game_id)
    Phoenix.PubSub.broadcast(Golf.PubSub, "game:#{game_id}", {:game_started, game})
  end

  def broadcast_game_event(game_id) do
    game = get_game(game_id)
    Phoenix.PubSub.broadcast(Golf.PubSub, "game:#{game_id}", {:game_event, game})
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

  def get_game(game_id) do
    Repo.get(Game, game_id)
    |> Repo.preload(players: players_query(game_id))
  end

  def player_query(game_id, user_id) do
    from p in Player, where: [game_id: ^game_id, user_id: ^user_id]
  end

  def get_player(game_id, user_id) do
    player_query(game_id, user_id)
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

  def add_player_to_game(%Game{} = game, %User{} = user) do
    turn = length(game.players)

    {:ok, player} =
      Ecto.build_assoc(game, :players, %{user_id: user.id, turn: turn})
      |> Repo.insert()

    broadcast_player_added(game.id, player)
    {:ok, player}
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
      Enum.map(cards, fn card -> %{"name" => card, "face_up?" => false} end)
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
