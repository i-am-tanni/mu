defmodule Mu.World.Zone do
  alias Mu.World.Zone.Events

  defstruct [:id, :name, :characters, :rooms, :items, :spawner]

  def initialized(zone), do: zone
  def event(context, event), do: Events.call(context, event)

  defimpl Kalevala.World.Zone.Callbacks do
    alias Mu.World.Zone

    @impl true
    def init(zone), do: zone

    def initialized(zone), do: Zone.initialized(zone)

    @impl true
    def event(_zone, context, event), do: Zone.event(context, event)
  end
end

defmodule Mu.World.Zone.SpawnEvent do
  import Kalevala.World.Zone.Context

  alias Mu.World.Zone.Spawner

  def spawn_character(context, event) do
    data = event.data
    loadout = Map.get(data, :loadout, [])

    {result, spawner} =
      Spawner.spawn_character(context.spawner, data.character_id, data.room_id, loadout)

    topic = if match?(:ok, result), do: "spawn/success", else: "spawn/failure"

    context
    |> put_data(:spawner, spawner)
    |> event(event.from_pid, self(), topic, event.data)
  end
end

defmodule Mu.World.Zone.Events do
  use Kalevala.Event.Router

  scope(Mu.World.Zone) do
    module(SpawnEvent) do
      event("spawn/character", :spawn_character)
    end
  end
end
