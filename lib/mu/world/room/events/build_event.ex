defmodule Mu.World.Room.BuildEvent do
  import Kalevala.World.Room.Context

  alias Mu.Character.BuildView
  alias Mu.Character.CommandView
  alias Mu.World.Kickoff
  alias Mu.World.Room
  alias Mu.World.Exit

  def dig(context, event = %{data: data}) do
    case !Enum.any?(context.data.exits, &Exit.matches?(&1, data.start_exit_name)) do
      true ->
        _dig(context, event)

      false ->
        context
        |> assign(:exit_name, data.start_exit_name)
        |> render(event.from_pid, BuildView, "exit-exists")
        |> assign(:character, event.acting_character)
        |> render(event.from_pid, CommandView, "prompt")
    end
  end

  defp _dig(context, event = %{data: data}) do
    end_room_id = Mu.World.parse_id(data.room_id)

    case GenServer.whereis(Kalevala.World.Room.global_name(end_room_id)) do
      nil ->
        start_exit = Exit.basic_exit(data.start_exit_name, context.data.id, end_room_id)
        end_exit = Exit.basic_exit(data.end_exit_name, end_room_id, context.data.id)

        room = %Room{
          id: end_room_id,
          zone_id: context.data.zone_id,
          exits: [end_exit],
          name: "Default Room",
          description: "Default Description"
        }

        Kickoff.start_room(room)

        context
        |> put_data(:exits, [start_exit | context.data.exits])
        |> event(event.from_pid, self(), event.topic, %{exit_name: data.start_exit_name})

      _ ->
        context
        |> assign(:room_id, end_room_id)
        |> render(event.from_pid, BuildView, "room-id-taken")
        |> assign(:character, event.acting_character)
        |> render(event.from_pid, CommandView, "prompt")
    end
  end
end
