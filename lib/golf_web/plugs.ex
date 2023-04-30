defmodule GolfWeb.Plugs do
  import Plug.Conn

  def ensure_user(conn, _) do
    with user_id when not is_nil(user_id) <- get_session(conn, "user_id"),
         user when not is_nil(user) <- Golf.Users.get_user(user_id) do
      conn
    else
      _ ->
        {:ok, user} = Golf.Users.create_user()
        put_session(conn, "user_id", user.id)
    end
  end
end
