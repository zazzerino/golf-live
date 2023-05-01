defmodule Golf.Games.ChatMessage do
  use Golf.Schema
  import Ecto.Changeset

  schema "chat_messages" do
    belongs_to :user, Golf.Users.User
    belongs_to :game, Golf.Games.Game

    field :content, :string
    field :username, :string, virtual: true

    timestamps()
  end

  @doc false
  def changeset(chat_message, attrs) do
    chat_message
    |> cast(attrs, [:user_id, :game_id, :content])
    |> validate_required([:user_id, :game_id, :content])
  end
end
