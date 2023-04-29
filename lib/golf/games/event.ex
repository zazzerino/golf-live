defmodule Golf.Games.Event do
  use Golf.Schema
  import Ecto.Changeset

  @actions [:take_deck, :take_table, :swap, :discard, :flip]

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
    |> cast(attrs, [:game_id, :player_id, :action, :hand])
    |> validate_required([:game_id, :player_id, :action, :hand])
  end
end
