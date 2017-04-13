defmodule TodoApi.Web.TodoResolver do
  @moduledoc"""
    The todo resolver
    proxies the graphql queries into our database queries
  """
  alias TodoApi.Schema.User
  alias TodoApi.Schema.User.Todo
  alias TodoApi.Schema.User.Label
  alias TodoApi.Repo
  import Ecto.Query

  def all(_args, %{context: %{current_user: current_user}}=info) do
    IO.inspect(current_user)
    todos = current_user
      |> Todo.find_todos_with_label()
      |> Repo.all()
    {:ok, todos}
  end

  

  @doc"""
    creates a todo
  """
  def create(%{labels: labels}=params, %{context: %{current_user: user}}) do
    #use multi for pushing in multiple transactions
    transaction = Repo.transaction(fn() -> 
      case Todo.create_changeset(user, params) |> Repo.insert() do
        {:error, message } -> Repo.rollback(message)
        {:ok, %Todo{id: id}=todo} ->
          label_status = Enum.map(labels, fn(label) ->
            IO.inspect(todo)
            case Label.create_changeset(user, todo, %{text: label}) |> Repo.insert do
              {:error, message } -> Repo.rollback(message)
              {:ok, label} -> {:ok, label}
            end
          end)
        todo
      end
    end)
    case transaction do
      {:error, message} -> {:error, message}
      {:ok, todo} -> {:ok, todo |> Repo.preload(:labels)}
    end
  end

  def create(params, %{context: %{current_user: user}}) do
    Todo.create_changeset(user, params) |> Repo.insert()
  end

  #note, I can prolly pullsome of this repeat logic into a seperate function
  def update(%{id: id} = params, %{context: %{current_user: user}}) do
    case Repo.get(Todo, id) do
      nil -> {:error, "todo does not exist"}
      %Todo{}=todo ->
        if todo.owner_id == user.id do
          Todo.update_changeset(todo, params)
            |> Repo.update()
        else
          {:error, "todo does not exist"}
        end
    end
  end

  def delete(%{id: id}, %{context: %{current_user: user}}) do
    case Repo.get(Todo, id) do
      nil -> {:error, "todo does not exist"}
      %Todo{}=todo ->
        if todo.owner_id == user.id do
           val = Repo.delete(todo)
           val
        else
          {:error, "todo does not exist"}
        end
    end
  end

  def add_label(%{id: id, label: label}, %{context: %{current_user: user}}) do
    get_todo_for_owner(id, user, fn(todo) -> 
      Label.create_changeset(user, todo, label) |> Repo.insert()
    end)
  end

  def remove_label(%{id: id, labels: text}, %{context: %{current_user: user}}) do
    get_todo_for_owner(id, user, fn(todo) -> 
      from(l in Ecto.Query.assoc(todo, :labels))
        |> where([l], l.text == ^text)
        |> first()
        |> Repo.delete()
    end)
  end

  defp get_todo_for_owner(id, user, func) do
    case Repo.get(Todo, id) do
      nil -> {:error, "todo does not exist"}
      %Todo{}=todo ->
        if todo.owner_id == user.id do
           func.call(todo)
        else
          {:error, "todo does not exist"}
        end
    end
  end


end