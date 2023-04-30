defmodule Golf.UserFixture do
  alias Golf.{Repo, User}

  def user_fixture(_attrs \\ %{}) do
    {:ok, user} = Repo.insert(%User{})
    user
  end
end
