defmodule Golf.Users do
  import Ecto.Query, warn: false

  alias Golf.Repo
  alias Golf.Users.User

  def get_user(user_id) do
    Repo.get(User, user_id)
  end

  def create_user() do
    Repo.insert(%User{})
  end

  def update_username(user_id, username) do
    from(u in User, where: [id: ^user_id], select: u)
    |> Repo.update_all(set: [username: username])
  end
end
