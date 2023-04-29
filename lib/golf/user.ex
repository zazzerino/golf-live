defmodule Golf.User do
  use Golf.Schema
  import Ecto.Changeset

  schema "users" do
    field :username, :string, default: "anon"

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username])
    |> validate_required([:username])
  end
end
