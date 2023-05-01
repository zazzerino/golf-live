defmodule Golf.GamesTest do
  use Golf.DataCase, async: true
  import Golf.UserFixture
  alias Golf.GamesDb

  describe "games" do
    test "create" do
      user1 = user_fixture()
      {:ok, %{game: game}} = GamesDb.create_game(user1)
      assert game.status == :init

      # game = GamesDb.get_game(game.id)
      # user2 = user_fixture()
      # {:ok, _} = GamesDb.add_player_to_game(game, user2)

      # game = GamesDb.get_game(game.id)
      # {:ok, _} = GamesDb.start_game(game) |> IO.inspect()

      # game = GamesDb.get_game(game.id)
      # IO.inspect(game)
    end
  end
end
