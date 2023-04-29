defmodule GolfWeb.GameController do
  use GolfWeb, :controller

  def create_game(conn, _) do
    user_id = get_session(conn, "user_id")
    user = Golf.Repo.get(Golf.User, user_id)
    {:ok, %{game: game}} = Golf.GamesDb.create_game(user)
    redirect(conn, to: ~p"/games/#{game.id}")
  end
end
