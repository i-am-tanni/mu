defmodule Mu.World.Kickoff do
  use GenServer

  alias Kalevala.World.RoomSupervisor
  alias Mu.World.Loader

  @doc false
  def start_link(opts) do
    config = Keyword.take(opts, [:start])
    otp_opts = Keyword.take(opts, [:name])

    GenServer.start_link(__MODULE__, config, otp_opts)
  end

  @doc false
  def reload() do
    GenServer.cast(__MODULE__, :reload)
  end

  @impl true
  def init(start: true) do
    {:ok, %{}, {:continue, :load}}
  end

  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast(:reload, state) do
    {:noreply, state, {:continue, :load}}
  end

  @impl true
  def handle_continue(:load, state) do
    world = Loader.load()

    Enum.each(world.items, &cache_item/1)
    Enum.each(world.characters, &cache_character/1)

    world.zones
    |> Enum.map(&Loader.strip_zone/1)
    |> Enum.each(&start_zone/1)

    world.zones
    |> Enum.each(fn zone ->
      Mu.World.ZoneCache.put(zone.id, zone)
    end)

    Enum.each(world.rooms, &start_room/1)
    Enum.each(world.zones, &start_spawners/1)

    {:noreply, state}
  end

  def start_spawners(zone) do
    zone_pid = GenServer.whereis(Kalevala.World.Zone.global_name(zone))

    characters_init = %Kalevala.Event{
      topic: "init/characters",
      from_pid: self(),
      data: %{}
    }

    items_init = %Kalevala.Event{
      topic: "init/items",
      from_pid: self(),
      data: %{}
    }

    send(zone_pid, characters_init)
    send(zone_pid, items_init)
  end

  def start_zone(zone) do
    config = %{
      supervisor_name: Mu.World,
      callback_module: Mu.World.Zone
    }

    case GenServer.whereis(Kalevala.World.Zone.global_name(zone)) do
      nil ->
        Kalevala.World.start_zone(zone, config)

      pid ->
        Kalevala.World.Zone.update(pid, zone)
    end
  end

  def start_room(room) do
    config = %{
      supervisor_name: RoomSupervisor.global_name(room.zone_id),
      callback_module: Mu.World.Room
    }

    item_instances = Map.get(room, :item_instances, [])
    room = Map.delete(room, :item_instances)

    case GenServer.whereis(Kalevala.World.Room.global_name(room)) do
      nil ->
        Kalevala.World.start_room(room, item_instances, config)

      pid ->
        Kalevala.World.Room.update_items(pid, item_instances)
        Kalevala.World.Room.update(pid, room)
    end
  end

  def cache_item(item) do
    Mu.World.Items.put(item.id, item)
  end

  def cache_character(character) do
    Mu.World.Characters.put(character.id, character)
  end
end
