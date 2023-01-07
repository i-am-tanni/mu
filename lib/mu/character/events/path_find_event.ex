defmodule Mu.Character.PathFindEvent do
  use Kalevala.Character.Event
  alias Mu.Character.PathFindView
  alias Mu.Character.CommandView

  def call(conn, %{data: data}) when data.success == true do
    case data.topic do
      "room/track" ->
        conn
        |> halt_pathfinding()
        |> assign(:exit_name, List.last(data.steps))
        |> render(PathFindView, "track/success")
        |> prompt(CommandView, "prompt")

      _ ->
        conn
    end
  end

  def call(conn = %{flash: %{path_find_data: path_find_data}}, event)
      when path_find_data.status == :continue and
             path_find_data.id == event.data.id do
    conn = decrement_leads(conn)

    case event.data.depth + 1 < event.data.max_depth do
      true -> try_propagate(conn, event)
      false -> test_for_failure(conn, event)
    end
  end

  def call(conn, _), do: conn

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
          | visited: MapSet.union(path_find_data.visited, unvisited),
            lead_count: path_find_data.lead_count + unvisited_count
        }

        conn
        |> put_flash(:path_find_data, path_find_data)
        |> propagate(event, MapSet.to_list(unvisited), room_exits)

      false ->
        test_for_failure(conn, event)
    end
  end

  # Check if leads are exhausted
  defp test_for_failure(conn, event) do
    path_find_data = get_flash(conn, :path_find_data)

    case path_find_data.lead_count > 0 do
      true ->
        conn

      false ->
        conn
        |> halt_pathfinding()
        |> assign(:text, event.data.text)
        |> render(PathFindView, "unknown")
        |> prompt(CommandView, "prompt")
    end
  end

  defp halt_pathfinding(conn) do
    path_find_data = %{conn.flash.path_find_data | status: :abort, visited: []}
    put_flash(conn, :path_find_data, path_find_data)
  end

  # Unvisited exits increase the lead count
  # Each unvisited exit that is pinged decrements the count when it reports back
  # If there are no unvisited exits left, failure state is achieved
  defp decrement_leads(conn = %{flash: %{path_find_data: path_find_data}}) do
    path_find_data = %{path_find_data | lead_count: path_find_data.lead_count - 1}
    put_flash(conn, :path_find_data, path_find_data)
  end

  # Propagate events to the unvisited rooms and add the exit_keywords to each event's steps
  defp propagate(conn, event, room_ids, room_exits) do
    event = %Kalevala.Event{
      acting_character: character(conn),
      from_pid: self(),
      topic: event.topic,
      data: %{event.data | depth: event.data.depth + 1}
    }

    events = Enum.map(room_ids, &update_steps(event, &1, room_exits))

    room_ids
    |> Enum.map(fn room_id ->
      Kalevala.World.Room.global_name(room_id)
    end)
    |> Enum.map(&GenServer.whereis/1)
    |> Enum.zip(events)
    |> Enum.each(fn {pid, event} ->
      send(pid, event)
    end)

    conn
  end

  defp update_steps(event, room_id, room_exits) do
    exit_name =
      Enum.find_value(room_exits, fn room_exit ->
        if room_exit.room_id == room_id, do: room_exit.exit_name
      end)

    steps = [exit_name | event.data.steps]
    %{event | data: Map.put(event.data, :steps, steps)}
  end
end
