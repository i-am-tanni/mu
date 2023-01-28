defmodule Mu.World.Room do
  require Logger

  alias Mu.World.Room.Events
  alias Mu.RoomChannel
  alias Mu.Communication
  alias Mu.World.Items

  defstruct [
    :id,
    :zone_id,
    :name,
    :description,
    exits: []
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

  def movement_request(_context, event, nil), do: {:abort, event, :no_exit}

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

  def load_item(item_instance), do: Items.get!(item_instance.item_id)

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
    module(BuildEvent) do
      event("room/dig", :dig)
    end

    module(LookEvent) do
      event("room/look", :call)
      event("room/look-arg", :arg)
      event("room/exits", :exits)
      event("peek/room", :peek_room)
    end

    module(PathFindEvent) do
      event("room/pathfind", :call)
      event("yell/send", :yell)
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

    module(DoorEvent) do
      event("room/open", :call)
      event("room/close", :call)
      event("door/open", :toggle_door)
      event("door/close", :toggle_door)
    end

    module(RandomExitEvent) do
      event("room/wander", :call)
    end

    module(WhisperEvent) do
      event("whisper/send", :call)
    end
  end
end

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

  def yell(context, event) do
    room_exits =
      context.data.exits
      |> Enum.map(fn room_exit ->
        %{room_id: room_exit.end_room_id}
      end)

    exit_name =
      reverse_find_local_exit(context, event.data.from_id)
      |> get_exit_name()

    data =
      event.data
      |> Map.put(:room_exits, room_exits)
      |> Map.put(:from_id, context.data.id)
      |> Map.put(:steps, [exit_name | event.data.steps])

    context
    |> event(event.from_pid, self(), event.topic, data)
  end

  defp get_exit_name(room_exit) do
    case !is_nil(room_exit) do
      true -> Map.get(room_exit, :exit_name, "nowhere")
      false -> "nowhere"
    end
  end

  defp reverse_find_local_exit(context, end_room_id) do
    Enum.find_value(context.data.exits, fn room_exit ->
      room_exit.end_room_id == end_room_id
    end)
  end

  defp find_local_character(context, name) do
    Enum.find(context.characters, fn character ->
      Kalevala.Character.matches?(character, name)
    end)
  end
end

defmodule Mu.World.Room.DoorEvent do
  import Kalevala.World.Room.Context
  alias Mu.World.Exit

  def call(context, event) do
    name = event.data.text
    room_exit = find_local_door(context, name)
    data = Map.put(event.data, :room_exit, room_exit)
    event(context, event.from_pid, self(), event.topic, data)
  end

  def toggle_door(context, event = %{data: %{door_id: door_id}}) do
    room_exit = find_local_door(context, door_id)

    case toggleable?(room_exit, event.topic) do
      true ->
        door = update_door(room_exit.door, event.topic)
        room_exit = Map.put(room_exit, :door, door)

        context
        |> pass(event)
        |> update_exit(room_exit)
        |> broadcast(event, params(context, event))

      false ->
        context
    end
  end

  defp find_local_door(context, keyword) do
    Enum.find(context.data.exits, fn room_exit ->
      (!is_nil(room_exit.door) && room_exit.door.id == keyword) ||
        (!is_nil(room_exit.door) && Exit.matches?(room_exit, keyword))
    end)
  end

  defp toggleable?(room_exit, _topic) when room_exit == nil, do: false

  defp toggleable?(%{door: door}, topic) do
    case topic do
      "door/open" -> door.closed?
      "door/close" -> door.closed? == false
      "door/lock" -> door.locked? == false
      "door/unlock" -> door.locked?
    end
  end

  defp update_door(door, action) do
    case action do
      "door/open" -> Map.put(door, :closed?, false)
      "door/close" -> Map.put(door, :closed?, true)
      "door/lock" -> Map.put(door, :locked?, true)
      "door/unlock" -> Map.put(door, :locked?, false)
    end
  end

  defp update_exit(context, room_exit) do
    exits = [room_exit | Enum.reject(context.data.exits, &Exit.matches?(&1, room_exit.id))]
    put_data(context, :exits, exits)
  end

  defp pass(context, event) when context.data.id == event.data.start_room_id do
    end_room_id = event.data.end_room_id

    end_room_id
    |> Kalevala.World.Room.global_name()
    |> GenServer.whereis()
    |> send(event)

    context
  end

  defp pass(context, _), do: context

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
