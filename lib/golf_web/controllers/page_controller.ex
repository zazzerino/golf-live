defmodule GolfWeb.PageController do
  use GolfWeb, :controller

  def home(conn, _params) do
    user_id = get_session(conn, "user_id")
    user = Golf.Repo.get(Golf.User, user_id)
    render(conn, :home, page_title: "Home", user: user)
  end
end
