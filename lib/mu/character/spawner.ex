defmodule Mu.Character.Spawner.Rules do
  @moduledoc """
  Rules for spawns:
  - Spawn count cannot exceed maximum.
  - Above the minimum_count, spawns occur at a frequency of minimum_delay to random_delay
  - room_ids is a list of rooms in which a spawn can occur, chosen at random
  - Automatic spawning is only triggered if minimum count > 0
  """
  defstruct [:minimum_count, :maximum_count, :minimum_delay, :random_delay, room_ids: []]
end

defmodule Mu.Character.Spawner.SpawnData do
  defstruct count: 0, instances: []
end

defmodule Mu.Character.SpawnerMeta do
  defstruct [:zone_id, :type, prototype_ids: [], spawns: %{}, rules: %{}]
end
