defmodule Mu.Character.OpenEvent do
  use Kalevala.Character.Event
  alias Mu.Character.OpenView
  alias Mu.Character.CommandView

  def call(conn, event = %{data: %{room_exit: room_exit}}) when room_exit != nil do
    door = room_exit.door
    text = event.data.text

    cond do
      door.closed? and not door.locked? ->
        params = %{
          start_room_id: room_exit.start_room_id,
          end_room_id: room_exit.end_room_id,
          direction: room_exit.exit_name,
          door_id: room_exit.door.id
        }

        conn
        |> event("door/open", params)

      door.closed? and door.locked? ->
        conn
        |> assign(:direction, text)
        |> prompt(OpenView, "door-locked")
        |> prompt(CommandView, "prompt", %{})

      true ->
        conn
        |> assign(:direction, text)
        |> prompt(OpenView, "door-already-open")
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def call(conn, event) do
    conn
    |> assign(:keyword, event.data.text)
    |> render(OpenView, "not-found")
    |> prompt(CommandView, "prompt", %{})
  end

  def notice(conn, event = %{data: data}) do
    conn
    |> assign(:character, event.acting_character)
    |> assign(:direction, data.direction)
    |> render(OpenView, notice_view(conn, event))
    |> prompt(CommandView, "prompt")
  end

  defp notice_view(conn, event) do
    cond do
      conn.character.id == event.acting_character.id ->
        "echo"

      event.data["side"] == "start" ->
        "listen-origin"

      event.data["side"] == "end" ->
        "listen-destination"
    end
  end
end
