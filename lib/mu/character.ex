defmodule Mu.Character.CombatFlash do
  @moduledoc """
  Temporary combat data that lives on the character in combat
  """
  defstruct turn_requested?: false,
            on_turn?: false,
            turn_queue: [],
            threat_table: %{}

  def put_combat_flash(conn, key, val) do
    combat_data = Map.get(conn.flash, :combat_data, %__MODULE__{})
    combat_data = %{combat_data | key => val}
    %{conn | flash: Map.put(conn.flash, :combat_data, combat_data)}
  end

  def get_combat_flash(conn, key) do
    conn.flash
    |> Map.get(:combat_data, %__MODULE__{})
    |> Map.get(key)
  end
end

defmodule Mu.Character.Instance do
  @moduledoc """
  Used for spawners to keep data about instances of characters they create
  """
  defstruct [:id, :character_id, :created_at, :expires_at]
end

defmodule Mu.Character.InitialEvent do
  @moduledoc """
  Initial events to kick off when a character starts
  """

  defstruct [:data, :delay, :topic]
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

  def put_equipment(conn, wear_slot, item_instance) do
    character = conn.character
    equipment = Equipment.put(character.meta.equipment, wear_slot, item_instance)
    character = %{character | meta: Map.put(character.meta, :equipment, equipment)}
    %{conn | character: character}
  end

  def get_equipment(conn, opts \\ []) do
    equipment = conn.character.meta.equipment

    case opts[:only] do
      "items" -> Map.values(Equipment.get(equipment))
      "sort_order" -> Equipment.sort_order(equipment)
      _ -> Equipment.get(equipment)
    end
  end

  def matches?(character, keyword) do
    keyword = String.downcase(keyword)

    character.id == keyword or
      String.downcase(character.name) == keyword or
      Enum.any?(character.meta.keywords, &(&1 == keyword))
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
    :mode,
    equipment: Mu.Character.Equipment.wear_slots(:basic),
    vitals: %Mu.Character.Vitals{},
    keywords: []
  ]

  defimpl Kalevala.Meta.Trim do
    def trim(meta) do
      Map.take(meta, [:vitals, :pronouns, :keywords])
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

  defstruct [:initial_events, :vitals, :zone_id, :mode, :aggressive?, :move_delay, :keywords]

  defimpl Kalevala.Meta.Trim do
    def trim(meta) do
      Map.take(meta, [:zone_id, :vitals, :keywords])
    end
  end

  defimpl Kalevala.Meta.Access do
    def get(meta, key), do: Map.get(meta, key)

    def put(meta, key, value), do: Map.put(meta, key, value)
  end
end
