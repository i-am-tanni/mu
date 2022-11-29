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

    module(SayEvent) do
      event("say/send", :call)
    end

    module(TellEvent) do
      event("tell/send", :call)
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
