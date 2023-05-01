defmodule Golf.Games do
  alias Golf.Games.{Game, Player}

  @card_names for rank <- ~w(A 2 3 4 5 6 7 8 9 T J Q K),
                  suit <- ~w(C D H S),
                  do: rank <> suit

  @decks_to_use 2
  def decks_to_use, do: @decks_to_use

  @max_players 4
  def max_players, do: @max_players

  @hand_size 6
  def hand_size, do: @hand_size

  # game logic

  def new_deck(1), do: @card_names
  def new_deck(n), do: @card_names ++ new_deck(n - 1)

  def new_deck(), do: new_deck(1)

  def deal_from_deck([], _) do
    {:error, :empty_deck}
  end

  def deal_from_deck(deck, n) when length(deck) < n do
    {:error, :not_enough_cards}
  end

  def deal_from_deck(deck, n) do
    {cards, deck} = Enum.split(deck, n)
    {:ok, cards, deck}
  end

  def deal_from_deck(deck) do
    with {:ok, [card], deck} <- deal_from_deck(deck, 1) do
      {:ok, card, deck}
    end
  end

  def current_player_turn(%Game{} = game) do
    num_players = length(game.players)
    rem(game.turn, num_players)
  end

  defguard is_players_turn(game, player) when rem(game.turn, length(game.players)) == player.turn

  def flip_card(hand, index) do
    List.update_at(hand, index, fn card -> Map.put(card, "face_up?", true) end)
  end

  def swap_card(hand, card_name, index) do
    old_card = Enum.at(hand, index) |> Map.get("name")
    hand = List.replace_at(hand, index, %{"name" => card_name, "face_up?" => true})
    {old_card, hand}
  end

  def flip_all(hand) do
    Enum.map(hand, fn card -> Map.put(card, "face_up?", true) end)
  end

  def num_cards_face_up(hand) do
    Enum.count(hand, fn card -> card["face_up?"] end)
  end

  def one_face_down?(hand) do
    num_cards_face_up(hand) == @hand_size - 1
  end

  def all_two_face_up?(players) do
    Enum.all?(players, fn p -> num_cards_face_up(p.hand) >= 2 end)
  end

  def all_face_up?(hand) do
    num_cards_face_up(hand) == @hand_size
  end

  def all_players_all_face_up?(players) do
    Enum.all?(players, fn p -> all_face_up?(p.hand) end)
  end

  defp face_down_cards(hand) do
    hand
    |> Enum.with_index()
    |> Enum.reject(fn {card, _} -> card["face_up?"] end)
    |> Enum.map(fn {_, index} -> String.to_existing_atom("hand_#{index}") end)
  end

  def playable_cards(%Game{status: :flip2}, %Player{} = player) do
    if num_cards_face_up(player.hand) < 2 do
      face_down_cards(player.hand)
    else
      []
    end
  end

  def playable_cards(%Game{} = game, %Player{} = player)
      when is_players_turn(game, player) do
    case game.status do
      s when s in [:flip2, :flip] ->
        face_down_cards(player.hand)

      s when s in [:take, :last_take] ->
        [:deck, :table]

      s when s in [:hold, :last_hold] ->
        [:held, :hand_0, :hand_1, :hand_2, :hand_3, :hand_4, :hand_5]

      _ ->
        []
    end
  end

  def playable_cards(_, _), do: []

  def rank_value(rank) when is_integer(rank) do
    case rank do
      ?K -> 0
      ?A -> 1
      ?2 -> 2
      ?3 -> 3
      ?4 -> 4
      ?5 -> 5
      ?6 -> 6
      ?7 -> 7
      ?8 -> 8
      ?9 -> 9
      r when r in [?T, ?J, ?Q] -> 10
    end
  end

  def rank_value(<<rank, _>>), do: rank_value(rank)

  defp rank_or_nil(%{"face_up?" => true, "name" => <<rank, _>>}), do: rank
  defp rank_or_nil(_), do: nil

  def score(hand, total \\ 0) do
    ranks = Enum.map(hand, &rank_or_nil/1)

    case ranks do
      # all match
      [a, a, a, a, a, a] when not is_nil(a) ->
        -40

      # outer cols match
      [a, b, a, a, c, a] when not is_nil(a) ->
        score([b, c], total - 20)

      # left 2 cols match
      [a, a, b, a, a, c] when not is_nil(a) ->
        score([b, c], total - 10)

      # right 2 cols match
      [a, b, b, c, b, b] when not is_nil(b) ->
        score([a, c], total - 10)

      # left col match
      [a, b, c, a, d, e] when not is_nil(a) ->
        score([b, c, d, e], total)

      # middle col match
      [a, b, c, d, b, e] when not is_nil(b) ->
        score([a, c, d, e], total)

      # right col match
      [a, b, c, d, e, c] when not is_nil(c) ->
        score([a, b, d, e], total)

      # left col match, 2nd pass
      [a, b, a, c] when not is_nil(a) ->
        score([b, c], total)

      # right col match, 2nd pass
      [a, b, c, b] when not is_nil(b) ->
        score([a, c], total)

      [a, a] when not is_nil(a) ->
        total

      _ ->
        ranks
        |> Enum.reject(&is_nil/1)
        |> Enum.reduce(0, fn name, acc -> rank_value(name) + acc end)
        |> Kernel.+(total)
    end
  end

  def hand_positions(num_players) do
    case num_players do
      1 -> [:bottom]
      2 -> [:bottom, :top]
      3 -> [:bottom, :left, :right]
      4 -> [:bottom, :left, :top, :right]
    end
  end
end
