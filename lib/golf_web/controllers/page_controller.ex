defmodule GolfWeb.PageController do
  use GolfWeb, :controller

  alias Golf.Users

  def home(conn, _) do
    user_id = get_session(conn, "user_id")
    user = Users.get_user(user_id)
    render(conn, :home, page_title: "Home", user: user)
  end

  def settings(conn, _) do
    user_id = get_session(conn, "user_id")
    user = Users.get_user(user_id)
    render(conn, :settings, page_title: "Settings", user: user)
  end

  def update_username(conn, %{"username" => username}) do
    user_id = get_session(conn, "user_id")
    {1, [_]} = Users.update_username(user_id, username)

    conn
    |> put_flash(:info, "Username updated.")
    |> redirect(to: "/settings")
  end
end
