defmodule Mu.Character do
  @moduledoc """
  Character callbacks for Kalevala
  """
  alias Mu.Character.Pronouns

  @doc """
  Converts the gender atom to a pronoun set.
  Pronoun strings don't live in PlayerMeta to avoid unnecessary data in event passing.
  Therefore, they must be filled in when needed by socials, etc.
  """
  def fill_pronouns(character) do
    meta = %{character.meta | pronouns: Pronouns.get(character.meta.pronouns)}
    Map.put(character, :meta, meta)
  end

  @doc """
  Like Enum.find except an ordinal is provided. Only the n-th match is returned.
  Ordinals are provided with "dot" notation e.g. `get 2.sword` for "get the second sword"

  If a negative ordinal is provided, the search will be conducted bottom to top.
  e.g. `get -2.sword` in natural language is equivalent to "get the SECOND TO LAST sword"

  """
  def find_nth(list, ordinal, fun) do
    cond do
      ordinal > 0 -> _find_nth(list, ordinal, fun)
      ordinal < 0 -> _find_nth(Enum.reverse(list), ordinal * -1, fun)
      true -> nil
    end
  end

  defp _find_nth([], _, _), do: nil
  defp _find_nth(list, 1, fun), do: Enum.find(list, fun)

  defp _find_nth([h | t], ordinal, fun) do
    case fun.(h) do
      true -> find_nth(t, ordinal - 1, fun)
      false -> find_nth(t, ordinal, fun)
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

  defstruct [:reply_to, :pronouns, vitals: %Mu.Character.Vitals{}]

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
