defmodule Mu.World.Room.PathFindEvent do
  import Kalevala.World.Room.Context

  def call(context, event) do
    character = find_local_character(context, event.data.text)

    case !is_nil(character) do
      true ->
        data = %{event.data | success: true}

        context
        |> event(event.from_pid, self(), event.topic, data)

      false ->
        room_exits =
          context.data.exits
          |> Enum.map(fn room_exit ->
            %{room_id: room_exit.end_room_id, exit_name: room_exit.exit_name}
          end)

        data = %{event.data | room_exits: room_exits}

        context
        |> event(event.from_pid, self(), event.topic, data)
    end
  end

  def yell(context, event) do
    room_exits =
      context.data.exits
      |> Enum.map(fn room_exit ->
        %{room_id: room_exit.end_room_id}
      end)

    exit_name =
      reverse_find_local_exit(context, event.data.from_id)
      |> get_exit_name()

    data =
      event.data
      |> Map.put(:room_exits, room_exits)
      |> Map.put(:from_id, context.data.id)
      |> Map.put(:steps, [exit_name | event.data.steps])

    context
    |> event(event.from_pid, self(), event.topic, data)
  end

  defp get_exit_name(room_exit) do
    case !is_nil(room_exit) do
      true -> Map.get(room_exit, :exit_name, "nowhere")
      false -> "nowhere"
    end
  end

  defp reverse_find_local_exit(context, end_room_id) do
    Enum.find_value(context.data.exits, fn room_exit ->
      room_exit.end_room_id == end_room_id
    end)
  end

  defp find_local_character(context, name) do
    Enum.find(context.characters, fn character ->
      Kalevala.Character.matches?(character, name)
    end)
  end
end
