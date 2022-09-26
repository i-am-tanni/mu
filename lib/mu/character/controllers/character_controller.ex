defmodule Mu.Character.CharacterController do
  use Kalevala.Character.Controller

  alias Kalevala.Character
  alias Mu.Character.CharacterView
  alias Mu.Character.MoveView

  @impl true
  def init(conn) do
    name = get_flash(conn, :username)
    process_character(conn, name)
  end

  @impl true
  def recv(conn, ""), do: conn

  defp process_character(conn, name) do
    character = build_character(name)

    conn
    |> put_character(character)
    |> move(:to, character.room_id, MoveView, "enter", %{})
    |> assign(:character, character)
    |> render(CharacterView, "name")
    |> event("room/look", %{})
  end

  defp build_character(name) do
    starting_room_id = 1

    %Character{
      id: Character.generate_id(),
      pid: self(),
      room_id: starting_room_id,
      name: name,
      status: "#{name} is here.",
      description: "#{name} is a person.",
      inventory: [],
      meta: %{}
    }
  end
end
