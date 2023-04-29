defmodule Golf.Games.Player do
  use Golf.Schema
  import Ecto.Changeset

  schema "players" do
    belongs_to :user, Golf.User
    belongs_to :game, Golf.Games.Game

    field :hand, {:array, :map}, default: []
    field :held_card, :string
    field :turn, :integer
    field :host?, :boolean, default: false

    has_many :events, Golf.Games.Event

    timestamps()
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:user_id, :game_id, :hand, :held_card, :turn, :host?])
    |> validate_required([:user_id, :game_id, :hand, :held_card, :turn, :host?])
  end
end
