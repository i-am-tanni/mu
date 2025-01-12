defmodule Mu.World.Kickoff do
  use GenServer

  alias Kalevala.World.RoomSupervisor
  alias Kalevala.World.CharacterSupervisor
  alias Mu.World.Loader
  alias Mu.World.Item
  alias Mu.World.NonPlayerRegistry

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

    send(zone_pid, characters_init)
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

    item_instances =
      room
      |> Map.get(:item_templates, [])
      |> Enum.map(fn
          %{item_id: item_id, opts: opts} -> Item.instance(item_id, opts)
          item_id -> Item.instance(item_id)
      end)

    room = Map.delete(room, :item_templates)

    case GenServer.whereis(Kalevala.World.Room.global_name(room)) do
      nil ->
        Kalevala.World.start_room(room, item_instances, config)

      pid ->
        Kalevala.World.Room.update_items(pid, item_instances)
        Kalevala.World.Room.update(pid, room)
    end
  end

  def spawn_mobile(mobile) do
    config = [
      supervisor_name: CharacterSupervisor.global_name(mobile.meta.zone_id),
      communication_module: Mu.Communication,
      initial_controller: Mu.Character.SpawnController,
      quit_view: {Mu.Character.QuitView, "disconnected"}
    ]
    instance_id = generate_mobile_id(mobile)
    mobile = %{mobile | id: instance_id}
    case Kalevala.World.start_character(mobile, config) do
      {:ok, pid} ->
        NonPlayerRegistry.register(instance_id, pid)
        {:ok, pid}

      error ->
        error
    end
  end

  defp generate_mobile_id(%{id: id}), do: generate_mobile_id(id)
  defp generate_mobile_id(id) do
    instance_id = "#{id}##{Kalevala.Character.generate_id()}"
    # if there is a collision, try again
    case NonPlayerRegistry.registered?(instance_id) do
      true -> generate_mobile_id(id)
      false -> instance_id
    end
  end

  def cache_item(item) do
    Mu.World.Items.put(item.id, item)
  end

  def cache_character(character) do
    Mu.World.NonPlayers.put(character.id, character)
  end
end
