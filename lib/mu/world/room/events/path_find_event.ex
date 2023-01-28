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

  defp find_local_character(context, name) do
    Enum.find(context.characters, fn character ->
      Kalevala.Character.matches?(character, name)
    end)
  end
end
