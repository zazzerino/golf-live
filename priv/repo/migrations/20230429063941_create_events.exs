defmodule Golf.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :game_id, references(:games)
      add :player_id, references(:players)

      add :action, :string
      add :hand_index, :integer

      timestamps()
    end
  end
end
