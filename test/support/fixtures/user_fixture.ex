defmodule Golf.UserFixture do
  alias Golf.Users

  def user_fixture() do
    {:ok, user} = Users.create_user()
    user
  end
end
