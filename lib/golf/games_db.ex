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
    Phoenix.PubSub.broadcast(Golf.PubSub, "game:#{game_id}", :game_started)
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

  def last_event_query(game_id) do
    from e in Event,
      where: [game_id: ^game_id],
      order_by: [desc: e.inserted_at],
      limit: 1
  end

  def get_game(game_id) do
    Repo.get(Game, game_id)
    |> Repo.preload(players: players_query(game_id), events: last_event_query(game_id))
  end

  def game_exists?(game_id) do
    from(g in Game, where: [id: ^game_id])
    |> Repo.exists?()
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

  def handle_game_event(%Game{}, %Player{}, %Event{}) do
  end
end
