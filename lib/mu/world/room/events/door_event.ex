defmodule Mu.World.Room.DoorEvent do
  import Kalevala.World.Room.Context
  import Mu.Utility

  require Logger
  alias Mu.World.Exit

  def call(context, event) do
    name = event.data.text
    room_exit = find_local_door(context, name)
    data = Map.put(event.data, :room_exit, room_exit)
    event(context, event.from_pid, self(), event.topic, data)
  end

  def toggle_door(context, event = %{data: %{door_id: door_id}}) do
    room_exit = find_local_door(context, door_id)

    case toggleable?(room_exit, event.topic) do
      true ->
        door = update_door(room_exit.door, event.topic)
        room_exit = Map.put(room_exit, :door, door)

        context
        |> pass(event)
        |> update_exit(room_exit)
        |> relay(event, params(context, event))

      false ->
        context
    end
  end

  defp find_local_door(context, keyword) do
    Enum.find(context.data.exits, fn room_exit ->
      if room_exit.type == :door,
        do: room_exit.door.id == keyword or Exit.matches?(room_exit, keyword)
    end)
  end

  defp toggleable?(nil, _topic), do: false

  defp toggleable?(%{door: door}, topic) do
    case topic do
      "door/open" -> door.closed?
      "door/close" -> door.closed? == false
      "door/lock" -> door.locked? == false
      "door/unlock" -> door.locked?
    end
  end

  defp update_door(door, action) do
    case action do
      "door/open" -> Map.put(door, :closed?, false)
      "door/close" -> Map.put(door, :closed?, true)
      "door/lock" -> Map.put(door, :locked?, true)
      "door/unlock" -> Map.put(door, :locked?, false)
    end
  end

  defp update_exit(context, room_exit) do
    exits = [room_exit | Enum.reject(context.data.exits, &Exit.matches?(&1, room_exit.id))]
    put_data(context, :exits, exits)
  end

  defp pass(context, event) when context.data.id == event.data.start_room_id do
    result =
      event.data.end_room_id
      |> Kalevala.World.Room.global_name()
      |> GenServer.whereis()

    case maybe(result) do
      {:ok, end_room_pid} -> send(end_room_pid, event)
      nil -> Logger.error("Room #{event.data.end_room_id} doesn't exist to receive DoorEvent.")
    end

    context
  end

  defp pass(context, _), do: context

  defp params(context, event) do
    params = %{direction: event.data.direction}

    case context.data.id == event.data.start_room_id do
      true -> Map.put(params, "side", "start")
      false -> Map.put(params, "side", "end")
    end
  end

  defp relay(context, event, params) do
    event = %Kalevala.Event{
      acting_character: event.acting_character,
      from_pid: event.from_pid,
      topic: event.topic,
      data: params
    }

    Enum.each(context.characters, fn character ->
      send(character.pid, event)
    end)

    context
  end
end
