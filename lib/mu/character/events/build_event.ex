defmodule Mu.Character.BuildEvent do
  use Kalevala.Character.Event

  alias Mu.Character.BuildView
  alias Mu.Character.EditController

  def dig(conn, %{data: %{exit_name: exit_name}}) do
    conn
    |> assign(:exit_name, exit_name)
    |> render(BuildView, "dig")
    |> request_movement(exit_name)
    |> assign(:prompt, false)
  end

  def edit_desc(conn, %{data: %{description: description}}) do
    EditController.put(conn, "Room Description", description, fn conn, text ->
      data = %{key: :description, val: text}

      conn
      |> event("room/set", data)
      |> assign(:prompt, false)
    end)
  end
end
