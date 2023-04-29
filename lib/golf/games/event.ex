defmodule Golf.Games.Event do
  use Golf.Schema
  import Ecto.Changeset
  alias __MODULE__

  @actions [:take_from_deck, :take_from_table, :swap, :discard, :flip]

  schema "events" do
    belongs_to :game, Golf.Games.Game
    belongs_to :player, Golf.Games.Player

    field :action, Ecto.Enum, values: @actions
    field :hand_index, :integer

    timestamps()
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:game_id, :player_id, :action, :hand_index])
    |> validate_required([:game_id, :player_id, :action])
  end

  def flip(game_id, player_id, hand_index) do
    %Event{action: :flip, game_id: game_id, player_id: player_id, hand_index: hand_index}
  end

  def swap(game_id, player_id, hand_index) do
    %Event{action: :swap, game_id: game_id, player_id: player_id, hand_index: hand_index}
  end

  def take_from_deck(game_id, player_id) do
    %Event{action: :take_from_deck, game_id: game_id, player_id: player_id}
  end

  def take_from_table(game_id, player_id) do
    %Event{action: :take_from_table, game_id: game_id, player_id: player_id}
  end

  def discard(game_id, player_id) do
    %Event{action: :discard, game_id: game_id, player_id: player_id}
  end
end
