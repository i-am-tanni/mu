defmodule Mu.World.Zone.Spawner.SpawnRules do
  defstruct [
    :prototype_id,
    :type,
    :minimum_count,
    :maximum_count,
    :minimum_delay,
    :random_delay,
    :expires_in,
    :room_ids
  ]
end

defmodule Mu.World.Zone.Spawner.InstanceTracking do
  defstruct instances: [], count: 0
end

defmodule Mu.World.Zone.Spawner do
  defstruct prototype_ids: [], instance_tracking: %{}, rules: %{}
end

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

defmodule Mu.World.Zone.Events do
  use Kalevala.Event.Router

  scope(Mu.World.Zone) do
    module(SpawnEvent) do
      event("spawn/character", :spawn_character)
    end
  end
end
