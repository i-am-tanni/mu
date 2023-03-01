defmodule Mu.Character.Instance do
  @moduledoc """
  Used for spawners to keep data about instances of characters they create
  """
  defstruct [:id, :character_id, :created_at, :expires_at]
end

defmodule Mu.Character do
  @moduledoc """
  Character callbacks for Kalevala
  """
  alias Mu.Character.Pronouns
  alias Mu.Character.Equipment

  @doc """
  Converts the gender atom to a pronoun set.
  Pronoun strings don't live in PlayerMeta to avoid unnecessary data in event passing.
  Therefore, they must be filled in when needed by socials, etc.
  """
  def fill_pronouns(character) do
    meta = %{character.meta | pronouns: Pronouns.get(character.meta.pronouns)}
    %{character | meta: meta}
  end

  def put_equipment(character, wear_slot, item_instance) do
    equipment = Equipment.put(character.meta.equipment, wear_slot, item_instance)
    %{character | meta: Map.put(character.meta, :equipment, equipment)}
  end

  def get_equipment(character, opts \\ []) do
    equipment = character.meta.equipment

    case opts[:only] do
      "items" -> Map.values(Equipment.get(equipment))
      "sort_order" -> Equipment.sort_order(equipment)
      _ -> Equipment.get(equipment)
    end
  end
end

defmodule Mu.Character.Vitals do
  @moduledoc """
  Character vital information
  """
  @derive Jason.Encoder

  defstruct [
    :health_points,
    :max_health_points,
    :skill_points,
    :max_skill_points,
    :endurance_points,
    :max_endurance_points
  ]
end

defmodule Mu.Character.PathFindData do
  @moduledoc """
  Tracks the list of visited room_ids and the number of leads.
  A lead = an unvisited exit.

  The search continues to propagate if:
  - the status remains :continue
  - there are unexplored exits (leads)
  - The search depth >= max_depth (lives in the event data)
  """
  defstruct [:id, :visited, :lead_count, :created_at, :status]
end

defmodule Mu.Character.PlayerMeta do
  @moduledoc """
  Specific metadata for a character in Mu
  """

  defstruct [
    :reply_to,
    :pronouns,
    equipment: Mu.Character.Equipment.wear_slots(:basic),
    vitals: %Mu.Character.Vitals{}
  ]

  defimpl Kalevala.Meta.Trim do
    def trim(meta) do
      Map.take(meta, [:vitals, :pronouns])
    end
  end

  defimpl Kalevala.Meta.Access do
    def get(meta, key), do: Map.get(meta, key)

    def put(meta, key, value), do: Map.put(meta, key, value)
  end
end

defmodule Mu.Character.NonPlayerMeta do
  @moduledoc """
  Specific metadata for a world character in Kantele
  """

  defstruct [:initial_events, :vitals, :zone_id]

  defimpl Kalevala.Meta.Trim do
    def trim(meta) do
      Map.take(meta, [:zone_id, :vitals])
    end
  end

  defimpl Kalevala.Meta.Access do
    def get(meta, key), do: Map.get(meta, key)

    def put(meta, key, value), do: Map.put(meta, key, value)
  end
end

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

  defimpl Kalevala.Meta.Trim do
    def trim(_meta), do: %{}
  end

  defimpl Kalevala.Meta.Access do
    def get(meta, key), do: Map.get(meta, key)

    def put(meta, key, value), do: Map.put(meta, key, value)
  end
end

defmodule Mu.Character.MuEnum do
  @moduledoc """
  Set of algorithms built on top of Elixir.Enum
  """

  @doc """
  Like Enum.find except an ordinal is provided. Only the n-th match is returned.
  Ordinals are provided with "dot" notation e.g. `get 2.sword` for "get the second sword"

  If a negative ordinal is provided, the search will be conducted bottom to top.
  e.g. `get -2.sword` in natural language is equivalent to "get the SECOND TO LAST sword"

  """
  def find(list, ordinal, fun) do
    list = to_enumerable(list)

    cond do
      ordinal > 0 -> _find(list, ordinal, fun)
      ordinal < 0 -> _find(Enum.reverse(list), ordinal * -1, fun)
      true -> nil
    end
  end

  defp _find([], _, _), do: nil
  defp _find(list, 1, fun), do: Enum.find(list, fun)

  defp _find([h | t], ordinal, fun) do
    case fun.(h) do
      true -> find(t, ordinal - 1, fun)
      false -> find(t, ordinal, fun)
    end
  end

  @doc """
  Like Enum.find except a count is provided. Returns a list of matches.
  Count is provided with 'star' notation:
  e.g. `drop 2*sword` in natural language is equivalent to "drop the first two swords"

  If a negative count is provided, the LAST matches are returned.
  e.g. `drop -2*sword` in natural language is equivalent to "drop the LAST two swords"
  """

  def find_many(list, count, fun) do
    list = to_enumerable(list)

    cond do
      count > 0 -> _find_many(list, count, [], fun)
      count < 0 -> _find_many(Enum.reverse(list), count * -1, [], fun)
      true -> []
    end
  end

  defp _find_many([], _, result, _), do: result

  defp _find_many(list, 1, result, fun) do
    case Enum.find(list, fun) do
      nil -> result
      item -> [item | result]
    end
  end

  defp _find_many([h | t], count, result, fun) do
    case fun.(h) do
      true -> _find_many(t, count - 1, [h | result], fun)
      false -> _find_many(t, count, result, fun)
    end
  end

  @doc """
  Like Enum.find_value(), except an ordinal is provided.
  Only the n-th value that is neither nil nor false returned by the function is the result.
  """
  def find_value(list, ordinal, fun) do
    list = to_enumerable(list)

    cond do
      ordinal > 0 -> _find_value(list, ordinal, fun)
      ordinal < 0 -> _find_value(Enum.reverse(list), ordinal * -1, fun)
      true -> nil
    end
  end

  defp _find_value([], _, _), do: nil
  defp _find_value(list, 1, fun), do: Enum.find_value(list, fun)

  defp _find_value([h | t], ordinal, fun) do
    result = fun.(h)

    case !is_nil(result) and result != false do
      true -> find_value(t, ordinal - 1, fun)
      false -> find_value(t, ordinal, fun)
    end
  end

  defp to_enumerable(list) do
    cond do
      is_map(list) -> Map.to_list(list)
      true -> list
    end
  end
end

defmodule Mu.Character.NonPlayerEvents do
  @moduledoc false

  use Kalevala.Event.Router

  alias Kalevala.Event.Movement

  scope(Mu.Character) do
    module(MoveEvent) do
      event(Movement.Commit, :commit)
      event(Movement.Abort, :abort)
      event(Movement.Notice, :notice)
    end

    module(WanderEvent) do
      event("room/wander", :run)
    end
  end
end
