defmodule Mu.World.Zone.BuildEvent do
  import Kalevala.World.Zone.Context

  alias Mu.World.Saver
  alias Mu.World.Room
  alias Mu.Character

  def put_room(context, %{data: %{room: %{id: room_id}}}) do
    zone = context.data
    put_data(context, :rooms, MapSet.put(zone.rooms, room_id))
  end

  def save(context, event) do
    zone = context.data
    caller_pid = event.from_pid

    # spin off a different process for saving
    #   and report result to caller

      rooms =
        # request room state from each room asnychronously
        MapSet.to_list(zone.rooms)
        |> Enum.map(fn room_id ->
          case Room.whereis(room_id) do
            nil ->
              error = "Unable to save #{room_id} in #{zone.id}. Does not exist."
              notify(caller_pid, "save/fail", %{error: error})
              raise(error)

            pid ->
              Task.async(fn -> GenServer.call(pid, :dump) end)
          end
        end)
        |> Enum.map(&Task.await(&1))

      rooms = Enum.map(rooms, fn %{data: room} -> room end)

      zone = %{zone | rooms: rooms}

      file_name = Inflex.underscore(zone.id)
      Saver.save_zone(zone, file_name)

      # attempt save and then report success or failure of the zone save to caller


    context
  end

  defp notify(pid, topic, data \\ %{}) do
    event = %Kalevala.Event{
      topic: topic,
      data: data,
      from_pid: self()
    }

    send(pid, event)
  end

end
