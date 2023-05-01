defmodule Golf.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages) do
      add :user_id, references(:users)
      add :game_id, references(:games)
      add :content, :string

      timestamps()
    end
  end
end
