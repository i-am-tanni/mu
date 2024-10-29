defmodule Mu.World.Zone.BuildEvent do
  import Kalevala.World.Zone.Context

  alias Mu.World.Saver
  alias Mu.World.Room
  alias Mu.World.NonPlayers
  alias Mu.World.Items

  def put_room(context, %{data: %{room: %{id: room_id}}}) do
    zone = context.data
    put_data(context, :rooms, MapSet.put(zone.rooms, room_id))
  end

  def save(context, event) do
    zone = context.data
    zone_id = zone.id

    rooms =
      # request room state from each room asnychronously
      MapSet.to_list(zone.rooms)
      |> Enum.map(fn room_id ->
          case Room.whereis(room_id) do
            nil ->
              error = "Cannot find room pid for #{zone.id}.#{room_id}."
              notify(event.from_pid, "save/fail", %{error: error})
              raise(error)

            pid ->
              Task.async(fn -> GenServer.call(pid, :dump) end)
          end
      end)
      |> Enum.map(&Task.await(&1))

    characters =
      for {template_id, _} <- zone.character_spawner,
          mobile = NonPlayers.get(template_id),
          match?(%{meta: %{zone_id: ^zone_id}}, mobile),
        do: mobile

    items =
      for %{item_templates: item_templates} <- rooms,
          %{zone_id: ^zone_id, id: item_id} <- item_templates,
          uniq: true,
        do: Items.get(item_id)

    zone = %{zone | rooms: rooms, characters: characters, items: items}

    file_name = Inflex.underscore(zone.id)
    Saver.save_zone(zone, file_name)

    event(context, event.from_pid, self(), "save/success", %{})

  end

  defp notify(pid, topic, data) do
    event = %Kalevala.Event{
      topic: topic,
      data: data,
      from_pid: self()
    }

    send(pid, event)
  end

end
