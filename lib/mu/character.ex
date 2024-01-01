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

defmodule Mu.Character.PlayerMeta do
  @moduledoc """
  Specific metadata for a character in Mu
  """

  defstruct [
    :reply_to,
    :pronouns,
    :mode,
    :equipment,
    :vitals,
    :target,
    :processing_action,
    action_queue: [],
    threat_table: %{},
    keywords: []
  ]

  defimpl Kalevala.Meta.Trim do
    def trim(meta) do
      Map.take(meta, [:vitals, :pronouns, :keywords, :mode, :target])
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

  defstruct [
    :initial_events,
    :vitals,
    :zone_id,
    :mode,
    :aggressive?,
    :move_delay,
    :keywords,
    :target,
    :processing_action,
    action_queue: [],
    threat_table: %{}
  ]

  defimpl Kalevala.Meta.Trim do
    def trim(meta) do
      Map.take(meta, [:zone_id, :vitals, :keywords, :mode, :target])
    end
  end

  defimpl Kalevala.Meta.Access do
    def get(meta, key), do: Map.get(meta, key)

    def put(meta, key, value), do: Map.put(meta, key, value)
  end
end

defmodule Mu.Character do
  @moduledoc """
  Character callbacks for Kalevala
  """
  import Kalevala.Character.Conn, only: [put_meta: 3, character: 1]

  alias Mu.Character.Pronouns
  alias Mu.Character.Equipment
  alias Mu.Character.CombatRequest
  alias Mu.Character.DamageSource

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
    equipment = Equipment.put(conn.character.meta.equipment, wear_slot, item_instance)
    put_meta(conn, :equipment, equipment)
  end

  def get_equipment(conn, opts \\ []) do
    opts = Enum.into(opts, %{})

    conn.character.meta.equipment
    |> Equipment.get(opts)
    |> Equipment.trim(opts)
  end

  def matches?(character, keyword) do
    keyword = String.downcase(keyword)

    character.id == keyword or
      String.downcase(character.name) == keyword or
      Enum.any?(character.meta.keywords, &(&1 == keyword))
  end

  def in_combat?(conn) do
    character = character(conn)
    character.meta.mode == :combat
  end

  def build_attack(_conn, target) do
    %CombatRequest{
      victims: target,
      hitroll: 4,
      verb: "punch",
      speed: 1,
      damages: [
        %DamageSource{
          type: :blunt,
          damroll: 1
        }
      ],
      effects: []
    }
  end

  def player?(character), do: match?(%Mu.Character.PlayerMeta{}, character.meta)
  def npc?(character), do: match?(%Mu.Character.NonPlayerMeta{}, character.meta)
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
