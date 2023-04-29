defmodule Golf.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:players) do
      add :user_id, references(:users)
      add :game_id, references(:games)

      add :hand, {:array, :map}
      add :held_card, :string
      add :turn, :integer
      add :host?, :boolean

      timestamps()
    end
  end
end
