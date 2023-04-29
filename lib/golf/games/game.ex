defmodule Golf.Games.Game do
  use Golf.Schema
  import Ecto.Changeset

  @statuses [:init, :flip2, :take, :hold, :flip, :last_take, :last_hold, :over]

  schema "games" do
    field :status, Ecto.Enum, values: @statuses
    field :turn, :integer
    field :deck, {:array, :string}
    field :table_cards, {:array, :string}, default: []

    has_many :players, Golf.Games.Player
    has_many :events, Golf.Games.Event

    timestamps()
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:status, :turn, :deck, :table_cards])
    |> validate_required([:status, :turn, :deck, :table_cards])
  end
end
