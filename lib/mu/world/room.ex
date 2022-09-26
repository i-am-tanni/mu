defmodule Mu.World.Room do
  alias Mu.World.Room.Events

  defstruct [
    :id,
    :zone_id,
    :name,
    :description,
    :exits
  ]

  def initialized(_room), do: :ok

  def event(context, event) do
    Events.call(context, event)
  end

  defimpl Kalevala.World.Room.Callbacks do
    require Logger

    alias Kalevala.World.BasicRoom
    alias Mu.World.Room

    @impl true
    def init(room), do: room

    @impl true
    def initialized(_room), do: :ok

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
    def item_request_pickup(_room, context, event, item_instance),
      do: BasicRoom.item_request_pickup(context, event, item_instance)
  end
end

defmodule Mu.World.Room.Events do
  use Kalevala.Event.Router

  scope(Mu.World.Room) do
    module(LookEvent) do
      event("room/look", :call)
    end
  end
end

defmodule Mu.World.Room.LookEvent do
  import Kalevala.World.Room.Context

  alias Mu.Character.LookView

  def call(context, event) do
    render(context, event.from_pid, LookView, "look")
  end
end
