defmodule Golf.Users do
  alias Golf.Users.User

  def get_user(user_id) do
    Golf.Repo.get(User, user_id)
  end

  def create_user(user \\ %User{}) do
    Golf.Repo.insert(user)
  end
end
