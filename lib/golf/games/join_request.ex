defmodule Golf.Games.JoinRequest do
  use Golf.Schema
  import Ecto.Changeset

  schema "join_requests" do
    belongs_to :game, Golf.Games.Game
    belongs_to :user, Golf.User

    field :confirmed?, :boolean, default: false
    field :username, :string, virtual: true

    timestamps()
  end

  @doc false
  def changeset(join_request, attrs) do
    join_request
    |> cast(attrs, [:game_id, :user_id, :confirmed?])
    |> validate_required([:game_id, :user_id, :confirmed?])
  end
end
