defmodule TodoApi.Web.UserResolver do
  alias TodoApi.Repo
  alias TodoApi.Schema.User
  alias TodoApi.Schema.User.Todo
  
  import Joken

  def find(%{id: id}, _info) do
    case TodoApi.Repo.get(User, id) do
      nil -> {:error, "User id #{id} not found"}
      user -> {:ok, user}
    end
  end

  def signup(%{email: email, password: password, password_confirmation: password_confirmation}=args, _info) do
    case User.signup_changeset(%User{}, args) |> Repo.insert() do
      {:error, changeset} -> {:error, changeset}
      {:ok, user} -> {:ok, Map.put(user, :jwt, sign_jwt(user))}
    end
  end

  def signin(%{email: email, password: password}) do

  end


  defp sign_jwt(%User{}=user) do
    secret = Application.get_env(:todo_api_web, TodoApi.Web.Endpoint)[:secret_key_base]
    payload = %{user_id: user.id}
      |> token()
      |> Joken.with_signer(hs256(secret))
      |> sign()
      |> get_compact()
  end

  


end