defmodule Mu.Character.YellEvent do
  use Kalevala.Character.Event
  require Logger

  alias Mu.Character.YellView
  alias Mu.Character.CommandView

  def interested?(event) do
    event.data.type == "yell" && match?("rooms:" <> _, event.data.channel_name)
  end

  def call(conn = %{flash: %{path_find_data: path_find_data}}, event)
      when path_find_data.id == event.data.id and event.data.depth + 1 < event.data.max_depth do
    conn
    |> broadcast(event)
    |> try_propagate(event)
  end

  def call(conn, _), do: conn

  def broadcast(conn, event) do
    options = [
      type: "yell",
      meta: %{
        from: List.first(event.data.steps),
        rooms_away: event.data.depth
      }
    ]

    conn
    |> publish_message("rooms:#{event.data.from_id}", event.data.text, options, &publish_error/2)
  end

  def echo(conn, event) do
    case conn.character.id != event.acting_character.id do
      true ->
        conn
        |> assign(:acting_character, event.acting_character)
        |> assign(:direction, event.data.meta.from)
        |> assign(:rooms_away, event.data.meta.rooms_away)
        |> assign(:text, event.data.text)
        |> render(YellView, "listen")
        |> render(CommandView, "prompt")

      false ->
        conn
        |> assign(:text, event.data.text)
        |> render(YellView, "echo")
        |> render(CommandView, "prompt")
    end
  end

  # Propagate to unvisited exits or test for failure
  defp try_propagate(conn, event) do
    room_exits = event.data.room_exits
    path_find_data = get_flash(conn, :path_find_data)

    room_ids =
      room_exits
      |> Enum.map(fn room_exit ->
        room_exit.room_id
      end)
      |> Enum.reduce(MapSet.new(), &MapSet.put(&2, &1))

    unvisited = MapSet.difference(room_ids, path_find_data.visited)
    unvisited_count = MapSet.size(unvisited)

    case _propagate? = unvisited_count > 0 do
      true ->
        path_find_data = %{
          path_find_data
          | visited: MapSet.union(path_find_data.visited, unvisited)
        }

        conn
        |> put_flash(:path_find_data, path_find_data)
        |> propagate(event, MapSet.to_list(unvisited))

      false ->
        conn
    end
  end

  # Propagate events to the unvisited rooms and add the exit_keywords to each event's steps
  defp propagate(conn, event = %{data: data}, room_ids) do
    data = %{event.data | depth: data.depth + 1}

    event = %Kalevala.Event{
      acting_character: character(conn),
      from_pid: self(),
      topic: event.topic,
      data: data
    }

    room_ids
    |> Enum.map(&Mu.World.Room.whereis/1)
    |> Enum.each(&send(&1, event))

    conn
  end

  defp publish_error(conn, error) do
    Logger.error("Tried to publish to a channel and failed - #{inspect(error)}")

    conn
  end
end
