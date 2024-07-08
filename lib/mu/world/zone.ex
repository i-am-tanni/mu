defmodule Mu.World.Zone.Spawner.SpawnRules do
  @moduledoc """
  Rules for spawning mobiles and items:
  - `:minimum_count` - the minimum number of mobiles that should be available *when the zone is first loaded*
  - `:maximum_count` - the maximum number of spawns allowed for this mobile
  - `:minimum_delay` - the minimum spawn timer before a mobile respawns
  - `:random_delay` - the maximum spawn timer before a mobile respawns. The time to respawn will be between the minimum and random delay.
  - `:room_ids` - List of room ids. Can contain repeats and order matters for the round_robin strategy.
  - `:strategy` - the strategy used to choose which room to spawn the mobile in. Options are `:random` or `:round_robin`.
  - `:round_robin_tail` - Only used for the round robin strategy.

  ######Round Robin
  The `:round_robin` strategy cuycles through the room_ids one by one and
    will spawn a mobile in each until the thresholds are reached.

  Will keep the remaining room_ids in the current cycle until the cycle is completed. Then it will start over.
  """

  defstruct [
    :minimum_count,
    :maximum_count,
    :minimum_delay,
    :random_delay,
    :expires_in,
    :room_ids,
    :strategy,
    round_robin_tail: []
  ]
end

defmodule Mu.World.Zone.Spawner do
  @moduledoc """
  Contains the information necessary to spawn an item or mobile prototype in a room.
  Will track a count of current instances and related information. Can be turned on or off.
  `:type` is either item or mobile.
  """
  alias __MODULE__.SpawnRules
  defstruct [:prototype_id, :active?, :type, count: 0, instances: [], rules: %SpawnRules{}]
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
    character_spawner: %{}
  ]

  def event(context, event), do: Events.call(context, event)

  defimpl Kalevala.World.Zone.Callbacks do
    alias Mu.World.Zone

    @impl true
    def init(zone), do: zone

    @impl true
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
    module(ResetEvent) do
      event("reset", :call)
    end
  end
end

defmodule Mu.World.Zone.ResetEvent do
  alias Mu.World.Kickoff

  def call(context, _event) do
    Enum.each(context.data.rooms, &Kickoff.start_room/1)
    context
  end
end
