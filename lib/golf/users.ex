defmodule Golf.Users do
  alias Golf.Repo
  alias Golf.Users.User

  def get_user(user_id) do
    Repo.get(User, user_id)
  end

  def create_user() do
    Repo.insert(%User{})
  end

  def update_username(%User{} = user, new_name) do
    user
    |> User.changeset(%{username: new_name})
    |> Repo.update()
  end
end
