defmodule Mu.World.Zone.BuildEvent do
  import Kalevala.World.Zone.Context
  alias Mu.World.Saver

  def put_room(context, %{data: %{room: room}}) do
    zone = context.data
    put_data(context, :rooms, [room | zone.rooms])
  end

  def save(context, event) do
    zone = context.data
    task = Task.async(fn -> Saver.save_zone(zone, event.data.file_name) end)
    IO.inspect(Task.await(task), label: "SAVE ZONE RESULT")
  end
end
