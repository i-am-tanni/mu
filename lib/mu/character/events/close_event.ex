defmodule Mu.Character.CloseEvent do
  use Kalevala.Character.Event
  alias Mu.Character.CloseView
  alias Mu.Character.CommandView

  def call(conn, event = %{data: %{room_exit: room_exit}}) when room_exit != nil do
    door = room_exit.door
    text = event.data.text

    cond do
      door.closed? == false ->
        params = %{
          start_room_id: room_exit.start_room_id,
          end_room_id: room_exit.end_room_id,
          direction: room_exit.exit_name,
          door_id: room_exit.door.id
        }

        conn
        |> event("door/close", params)

      door.closed? ->
        conn
        |> assign(:direction, text)
        |> render(CloseView, "door-already-closed")
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def call(conn, event) do
    conn
    |> assign(:keyword, event.data.text)
    |> render(CloseView, "not-found")
    |> prompt(CommandView, "prompt", %{})
  end

  def notice(conn, event = %{data: data}) do
    conn
    |> assign(:character, event.acting_character)
    |> assign(:direction, data.direction)
    |> render(CloseView, notice_view(conn, event))
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
