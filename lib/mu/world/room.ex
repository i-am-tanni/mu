defmodule Mu.World.Room do
  require Logger

  alias Mu.World.Room.Events
  alias Mu.RoomChannel
  alias Mu.Communication
  alias Mu.World.Items
  alias Kalevala.World.BasicRoom

  defstruct [
    :id,
    :zone_id,
    :name,
    :description,
    :round_queue,
    :next_round_queue,
    :round_in_process?,
    exits: []
  ]

  def whereis(room_id) do
    room_id
    |> Kalevala.World.Room.global_name()
    |> GenServer.whereis()
  end

  @doc """
  Called after a room is initialized, used in the Callbacks protocol
  """
  def initialized(room) do
    options = [room_id: room.id]

    with {:error, _reason} <- Communication.register("rooms:#{room.id}", RoomChannel, options) do
      Logger.warn("Failed to register the room's channel, did the room restart?")

      :ok
    end

    room
  end

  def movement_request(_context, event, nil), do: {:abort, event, :no_exit}

  def movement_request(_context, event, room_exit) when room_exit.type == :normal do
    {:proceed, event, room_exit}
  end

  def movement_request(_context, event, room_exit = %{type: :door, door: nil}) do
    exit_info = "#{room_exit.start_room_id}/#{room_exit.id}.#{room_exit.exit_name}"
    Logger.warn("Room_exit #{exit_info} type is :door but door data is nil.")
    {:proceed, event, room_exit}
  end

  def movement_request(_context, event, room_exit = %{type: :door, door: door}) do
    cond do
      door.closed? == false -> {:proceed, event, room_exit}
      door.locked? -> {:abort, event, :door_locked}
      door.closed? -> {:abort, event, :door_closed}
    end
  end

  def confirm_movement(context, event) when context.data.id == event.data.to do
    from_room_id = event.data.from
    entrance = Enum.find(context.data.exits, &(&1.end_room_id == from_room_id))
    entrance_name = entrance.exit_name
    event = %{event | data: Map.put(event.data, :entrance_name, entrance_name)}
    {context, event}
  end

  def confirm_movement(context, event) do
    {context, event}
  end

  def item_request_pickup(context, event, item_instance) do
    BasicRoom.item_request_pickup(context, event, item_instance)
  end

  def item_request_drop(context, event, item_instance) do
    BasicRoom.item_request_drop(context, event, item_instance)
  end

  def load_item(item_instance), do: Items.get!(item_instance.item_id)

  def event(context, event) do
    Events.call(context, event)
  end

  defimpl Kalevala.World.Room.Callbacks do
    require Logger
    alias Mu.World.Room

    @impl true
    def init(room), do: room

    @impl true
    def initialized(room), do: Room.initialized(room)

    @impl true
    def event(_room, context, event), do: Room.event(context, event)

    @impl true
    def exits(room), do: room.exits

    @impl true
    def movement_request(_room, context, event, room_exit),
      do: Room.movement_request(context, event, room_exit)

    @impl true
    def confirm_movement(_room, context, event),
      do: Room.confirm_movement(context, event)

    @impl true
    def item_request_drop(_room, context, event, item_instance),
      do: Room.item_request_drop(context, event, item_instance)

    @impl true
    def load_item(_room, item_instance), do: Room.load_item(item_instance)

    @impl true
    def item_request_pickup(_room, context, event, item_instance),
      do: Room.item_request_pickup(context, event, item_instance)
  end
end

defmodule Mu.World.Room.Events do
  use Kalevala.Event.Router

  scope(Mu.World.Room) do
    module(BuildEvent) do
      event("room/dig", :dig)
    end

    module(CombatEvent) do
      event("combat/request", :request)
      event("combat/abort", :abort)
      event("combat/kickoff", :commit)
      event("combat/commit", :commit)
      event("combat/flee", :flee)
    end

    module(ListEvent) do
      event("room/chars", :characters)
    end

    module(CombatRoundEvent) do
      event("round/push", :push)
      event("round/pop", :pop)
      event("round/cancel", :cancel)
      event("death", :death)
    end

    module(CommunicationEvent) do
      event("say/send", :say)
      event("social/send", :social)
      event("tell/send", :tell)
      event("whisper/send", :whisper)
      event("yell/send", :yell)
    end

    module(ForwardEvent) do
      event("npc/wander", :call)
    end

    module(ItemEvent) do
      event("room/get-from", :get_from)
      event("room/put-in", :put)
    end

    module(MoveEvent) do
      event(Kalevala.Event.Movement.Notice, :call)
    end

    module(LookEvent) do
      event("room/look", :call)
      event("room/look-arg", :arg)
      event("room/exits", :exits)
      event("peek/room", :peek_room)
    end

    module(PathFindEvent) do
      event("room/pathfind", :call)
    end

    module(DoorEvent) do
      event("room/open", :call)
      event("room/close", :call)
      event("door/open", :toggle_door)
      event("door/close", :toggle_door)
    end

    module(RandomExitEvent) do
      event("room/wander", :call)
    end

    module(TerminateEvent) do
      event("room/terminate", :call)
    end
  end
end

defmodule Mu.World.Room.ForwardEvent do
  import Kalevala.World.Room.Context

  def call(context, event) do
    event(context, event.from_pid, self(), event.topic, event.data)
  end
end
