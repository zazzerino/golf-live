defmodule GolfWeb.Plugs do
  import Plug.Conn

  def put_user(conn, _) do
    if get_session(conn, "user_id") do
      conn
    else
      {:ok, user} = Golf.Repo.insert(%Golf.User{})
      put_session(conn, "user_id", user.id)
    end
  end
end
