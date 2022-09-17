defmodule Mu.World.Room do
  def initialized(room), do: :ok

  def event(context, event) do
    alias Kalevala.World.Room.Context
    IO.inspect(event)
    event(context, event.from_id, self(), event.topic, event.data)
  end

  defimpl Kalevala.World.Room.Callbacks do
    require Logger

    alias Kalevala.World.BasicRoom
    alias Mu.World.Room

    @impl true
    def init(room), do: room

    @impl true
    def initialized(room), do: :ok

    @impl true
    def event(_room, context, event), do: Room.event(context, event)

    @impl true
    def exits(room), do: room.exits

    @impl true
    def movement_request(_room, context, event, room_exit),
      do: BasicRoom.movement_request(context, event, room_exit)

    @impl true
    def confirm_movement(_room, context, event),
      do: BasicRoom.confirm_movement(context, event)

    @impl true
    def item_request_drop(_room, context, event, item_instance),
      do: BasicRoom.item_request_drop(context, event, item_instance)

    @impl true
    def load_item(_room, item_instance), do: Room.load_item(item_instance)

    @impl true
    def item_request_pickup(room, context, event, item_instance),
      do: BasicRoom.item_request_pickup(context, event, item_instance)
  end
end
