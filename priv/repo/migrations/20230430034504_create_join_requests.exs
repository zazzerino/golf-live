defmodule Golf.Repo.Migrations.CreateJoinRequests do
  use Ecto.Migration

  def change do
    create table(:join_requests) do
      add :game_id, references(:games)
      add :user_id, references(:users)
      add :confirmed?, :boolean

      timestamps()
    end
  end
end
