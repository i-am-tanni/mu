defmodule Mu.World.Room do
  require Logger

  alias Mu.World.Room.Events
  alias Mu.RoomChannel
  alias Mu.Communication

  defstruct [
    :id,
    :zone_id,
    :name,
    :description,
    :exits
  ]

  @doc """
  Called after a room is initialized, used in the Callbacks protocol
  """
  def initialized(room) do
    options = [room_id: room.id]

    with {:error, _reason} <- Communication.register("rooms:#{room.id}", RoomChannel, options) do
      Logger.warn("Failed to register the room's channel, did the room restart?")

      :ok
    end
  end

  def movement_request(_context, event, room_exit) when room_exit.door == nil do
    {:proceed, event, room_exit}
  end

  def movement_request(_context, event, room_exit = %{door: door}) do
    cond do
      door.closed? == false -> {:proceed, event, room_exit}
      door.locked? -> {:abort, event, :door_locked}
      door.closed? -> {:abort, event, :door_closed}
    end
  end

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

    module(OpenEvent) do
      event("room/open", :call)
      event("door/open", :open_door)
    end

    module(SayEvent) do
      event("say/send", :call)
    end

    module(SocialEvent) do
      event("social/send", :call)
    end

    module(TellEvent) do
      event("tell/send", :call)
    end

    module(RandomExitEvent) do
      event("room/wander", :call)
    end

    module(WhisperEvent) do
      event("whisper/send", :call)
    end
  end
end

defmodule Mu.World.Room.LookEvent do
  import Kalevala.World.Room.Context

  alias Mu.Character.LookView
  alias Mu.World.Items

  def call(context, event) do
    characters =
      Enum.reject(context.characters, fn character ->
        character.id == event.acting_character.id
      end)

    item_instances =
      Enum.map(context.item_instances, fn item_instance ->
        %{item_instance | item: Items.get!(item_instance.item_id)}
      end)

    context
    |> assign(:room, context.data)
    |> assign(:characters, characters)
    |> assign(:item_instances, item_instances)
    |> render(event.from_pid, LookView, "look")
    |> render(event.from_pid, LookView, "look.extra")
  end
end

defmodule Mu.World.Room.OpenEvent do
  import Kalevala.World.Room.Context
  alias Kalevala.World.Room
  alias Mu.World.Exit

  def call(context, event) do
    name = event.data.text
    room_exit = find_local_door(context, name)
    data = Map.put(event.data, :room_exit, room_exit)
    event(context, event.from_pid, self(), event.topic, data)
  end

  def open_door(context, event = %{data: %{door_id: door_id}}) do
    room_exit = find_local_door(context, door_id)

    case room_exit != nil do
      true ->
        door = Map.put(room_exit.door, :closed?, false)
        room_exit = Map.put(room_exit, :door, door)

        context
        |> pass_along(event)
        |> update_exit(room_exit)
        |> broadcast(event, params(context, event))

      false ->
        context
    end
  end

  defp find_local_door(context, keyword) do
    Enum.find(context.data.exits, fn room_exit ->
      (room_exit.door && room_exit.door.id == keyword) ||
        (room_exit.door && Exit.matches?(room_exit, keyword))
    end)
  end

  defp update_exit(context, room_exit) do
    exits = [room_exit | Enum.reject(context.data.exits, &Exit.matches?(&1, room_exit.id))]
    put_data(context, :exits, exits)
  end

  defp pass_along(context, event) when context.data.id == event.data.start_room_id do
    end_room_id = event.data.end_room_id

    Room.global_name(end_room_id)
    |> GenServer.whereis()
    |> send(event)

    context
  end

  defp pass_along(context, _), do: context

  defp params(context, event) do
    params = %{direction: event.data.direction}

    case context.data.id == event.data.start_room_id do
      true -> Map.put(params, "side", "start")
      false -> Map.put(params, "side", "end")
    end
  end

  defp broadcast(context, event, params) do
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

defmodule Mu.World.Room.RandomExitEvent do
  import Kalevala.World.Room.Context

  def call(context, event) do
    exits =
      Enum.map(context.data.exits, fn room_exit ->
        room_exit.exit_name
      end)

    event(context, event.from_pid, self(), event.topic, %{exits: exits})
  end
end

defmodule Mu.World.Room.SayEvent do
  import Kalevala.World.Room.Context

  def call(context, event) do
    name = event.data["at"]
    character = find_local_character(context, name)
    data = Map.put(event.data, "at_character", character)
    event(context, event.from_pid, self(), event.topic, data)
  end

  defp find_local_character(context, name) do
    Enum.find(context.characters, fn character ->
      Kalevala.Character.matches?(character, name)
    end)
  end
end

defmodule Mu.World.Room.SocialEvent do
  import Kalevala.World.Room.Context

  def call(context, event) do
    name = event.data.name
    character = find_local_character(context, name)
    data = Map.put(event.data, :character, character)
    event(context, event.from_pid, self(), event.topic, data)
  end

  defp find_local_character(context, name) do
    Enum.find(context.characters, fn character ->
      Kalevala.Character.matches?(character, name)
    end)
  end
end

defmodule Mu.World.Room.TellEvent do
  import Kalevala.World.Room.Context

  def call(context, event) do
    name = event.data.name
    character = find_local_character(context, name) || find_player_character(name)
    data = Map.put(event.data, :character, character)
    event(context, event.from_pid, self(), event.topic, data)
  end

  defp find_local_character(context, name) do
    find_character(context.characters, name)
  end

  defp find_player_character(name) do
    characters = Mu.Character.Presence.characters()
    find_character(characters, name)
  end

  defp find_character(characters, name) do
    Enum.find(characters, fn character ->
      Kalevala.Character.matches?(character, name)
    end)
  end
end

defmodule Mu.World.Room.WhisperEvent do
  import Kalevala.World.Room.Context

  def call(context, event) do
    name = event.data.name
    character = find_local_character(context, name)
    data = Map.put(event.data, :character, character)
    event(context, event.from_pid, self(), event.topic, data)
  end

  defp find_local_character(context, name) do
    Enum.find(context.characters, fn character ->
      Kalevala.Character.matches?(character, name)
    end)
  end
end

defmodule Mu.World.Room.NotifyEvent do
  import Kalevala.World.Room.Context

  def call(context, event) do
    Enum.reduce(context.characters, context, fn character, context ->
      event(context, character.pid, event.from_pid, event.topic, event.data)
    end)
  end
end
