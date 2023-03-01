defmodule Mu.World.Zone.Spawner.SpawnRules do
  defstruct [
    :minimum_count,
    :maximum_count,
    :minimum_delay,
    :random_delay,
    :expires_in,
    :room_ids
  ]
end

defmodule Mu.World.Zone.Spawner do
  defstruct [:prototype_id, :active?, :type, count: 0, instances: [], rules: %{}]
end

defmodule Mu.World.Zone do
  alias Mu.World.Zone.Events
  alias Kalevala.World.Zone

  defstruct [
    :id,
    :name,
    :characters,
    :rooms,
    :items,
    character_spawner: %{},
    item_spawner: %{}
  ]

  def event(context, event), do: Events.call(context, event)

  defimpl Kalevala.World.Zone.Callbacks do
    alias Mu.World.Zone

    @impl true
    def init(zone), do: zone

    def initialized(zone), do: zone

    @impl true
    def event(_zone, context, event), do: Zone.event(context, event)
  end
end

defmodule Mu.World.Zone.Events do
  use Kalevala.Event.Router

  scope(Mu.World.Zone) do
    module(SpawnEvent) do
      event("init/characters", :call)
      event("init/items", :call)
      event("spawn/character", :call)
    end
  end
end
