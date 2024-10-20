defmodule Mu.World.Room.ExtraDesc do
  @moduledoc """
  A keyword that can be examined in the room
  Any instances of the keyword will be highlighted in the description unless hidden is true
  """
  defstruct [:keyword, :description, :hidden?, :highlight_color_override]
end

defmodule Mu.World.Room do
  require Logger

  alias Mu.World.Room.Events
  alias Mu.RoomChannel
  alias Mu.Communication
  alias Mu.World.Items
  alias Kalevala.World.BasicRoom

  defstruct [
    :id,
    :template_id,
    :zone_id,
    :name,
    :x,
    :y,
    :z,
    :symbol,
    :description,
    :round_queue,
    :next_round_queue,
    :round_in_process?,
    exits: [],
    extra_descs: [],
    item_templates: []
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
      Logger.warning("Failed to register the room's channel, did the room restart?")

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
    Logger.warning("Room_exit #{exit_info} type is :door but door data is nil.")
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


defmodule Mu.World.Room.RoomId do
  @moduledoc """
  Cache for looking up integer room ids generated from string identifiers sourced from the room data.
  Ids are generated from a hash provided the room string identifier.
  """

  defstruct [ids: MapSet.new(), collisions: %{}]

  @i32_max Integer.pow(2, 31) - 1

  @default_path "data/world"

  # public interface

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    world_path = Keyword.get(opts, :world_path, @default_path)

    keys =
      for path <- load_folder(world_path),
          String.match?(path, ~r/\.json$/),
          zone_data = Jason.decode!(File.read!(path)),
          %{"zone" => %{"id" => zone_id}, "rooms" => rooms} = zone_data,
          room_id <- Map.keys(rooms) do
        # key that we use to generate the room id
        "#{zone_id}:#{room_id}"
      end

    {key_vals, {collisions, used_ids}} =
      Enum.map_reduce(keys, {%{}, MapSet.new()}, fn key, {collisions, ids} ->
        case generate_id(key, collisions, ids) do
          {:ok, id} ->
            acc = {collisions, MapSet.put(ids, id)}
            {{key, id}, acc}

          {:collision, id, replacement} ->
            collision = %{collision_id: id, replacement: replacement}
            collisions = Map.put(collisions, key, collision)
            acc = {collisions, MapSet.put(ids, replacement)}
            {{key, replacement}, acc}
        end
      end)

    :ets.new(__MODULE__, [:set, :named_table])
    Enum.each(key_vals, &:ets.insert(__MODULE__, &1))

    state = %__MODULE__{
      ids: used_ids,
      collisions: collisions
    }

    {:ok, state}
  end

  def get!(key) do
    with :error <- unwrap(lookup(key)) do
      # restart RoomIdCache process if there is an issue
      #   and raise an error in the calling process
      Process.exit(GenServer.whereis(__MODULE__), :kill)
      raise("Could not find expected room id for key: #{key}")
    end
  end

  def put(data), do: GenServer.call(__MODULE__, {:put, data})

  # private

  def handle_call({:put, key}, _from, state) when is_binary(key) do
    %{ids: ids, collisions: collisions} = state

    {id, collisions} =
      case generate_id(key, collisions, ids) do
        {:ok, id} ->
          {id, collisions}

        {:collision, id, replacement} ->
          collision = %{collision_id: id, replacement: replacement}
          collisions = Map.put(collisions, key, collision)
          {replacement, collisions}
      end

    state = %{state |
      ids: MapSet.put(ids, id),
      collisions: collisions
    }

    :ets.insert(__MODULE__, {key, id})

    {:reply, id, state}
  end

  def handle_call({:put, keys}, _from, state) when is_list(keys) do
    %{ids: ids, collisions: collisions} = state

    {new_ids, {collisions, ids}} =
      Enum.map_reduce(keys, {collisions, ids}, fn key, {collisions, ids} ->
          case generate_id(key, collisions, ids) do
            {:ok, id} ->
              acc = {collisions, MapSet.put(ids, id)}
              {id, acc}

            {:collision, id, replacement} ->
              collision = %{collision_id: id, replacement: replacement}
              collisions = Map.put(collisions, key, collision)
              acc = {collisions, MapSet.put(ids, replacement)}
              {replacement, acc}
          end
      end)

    Stream.zip(keys, new_ids)
    |> Enum.each(&:ets.insert(__MODULE__, &1))

    state = %{state | ids: ids, collisions: collisions}

    {:reply, new_ids, state}
  end

  # helpers

  def load_folder(path, acc \\ []) do
    Enum.reduce(File.ls!(path), acc, fn file, acc ->
      path = Path.join(path, file)

      case String.match?(file, ~r/\./) do
        true -> [path | acc]
        false -> load_folder(path, acc)
      end
    end)
  end

  defp lookup(key) do
    case :ets.lookup(__MODULE__, key) do
      [{_, id}] -> {:ok, id}
      _ -> :error
    end
  end

  defp unwrap({:ok, result}), do: result
  defp unwrap(error), do: error

  defp generate_id(key, collisions, _) when is_map_key(collisions, key) do
    %{replacement: override} = collisions[key]
    {:ok, override}
  end

  defp generate_id(key, _, ids) do
    with :error <- lookup(key) do
      id = string_to_i32(key)
      case MapSet.member?(ids, id) do
        true -> {:collision, id, linear_probe(id + 1, ids)}
        false -> {:ok, id}
      end
    end
  end

  defp string_to_i32(s) when is_binary(s) do
    hash = :crypto.hash(:sha256, s)
    val = :binary.decode_unsigned(hash)
    # subtract 1 and add after because the lowest possible value we want is 1
    rem(val, @i32_max - 1) + 1
  end

  defp linear_probe(id, ids) when id > @i32_max, do:
    linear_probe(1, ids)

  defp linear_probe(id, ids) do
    case MapSet.member?(ids, id) do
      true -> linear_probe(id + 1, ids)
      false -> id
    end
  end

end
