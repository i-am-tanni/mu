defmodule Mu.Character.Guards do
  defguard is_non_player(conn) when is_struct(conn.character.meta, Mu.Character.NonPlayerMeta)
  defguard is_player(conn) when is_struct(conn.character.meta, Mu.Character.PlayerMeta)
  defguard in_combat(conn) when conn.character.meta.in_combat?
  defguard is_hunting(conn) when is_struct(conn.controller, Mu.Character.HuntController)
  defguard is_pathing(conn) when is_struct(conn.controller, Mu.Character.PathController)
  defguard is_character(character) when is_struct(character, Kalevala.Character)
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

defmodule Mu.Character.PlayerMeta do
  @moduledoc """
  Specific metadata for a character in Mu
  """

  defstruct [
    :reply_to,
    :pronouns,
    :pose,
    :equipment,
    :vitals,
    :target,
    :in_combat?,
    :processing_action,
    action_queue: [],
    threat_table: %{},
    keywords: []
  ]

  defimpl Kalevala.Meta.Trim do
    def trim(meta) do
      keys = [:vitals, :pronouns, :keywords, :pose, :in_combat?]
      Map.take(meta, keys)
    end
  end

  defimpl Kalevala.Meta.Access do
    def get(meta, key), do: Map.get(meta, key)

    def put(meta, key, value), do: Map.put(meta, key, value)
  end
end

defmodule Mu.Character.NonPlayerMeta do
  @moduledoc """
  Specific metadata for a world character
  """

  defstruct [
    :zone_id,
    :keywords,
    :flags,
    :vitals,
    :pose,
    :move_delay,
    :initial_events,
    :target,
    :in_combat?,
    :processing_action,
    action_queue: [],
    threat_table: %{}
  ]

  defimpl Kalevala.Meta.Trim do
    def trim(meta) do
      keys = [:zone_id, :vitals, :keywords, :pose, :in_combat?]
      Map.take(meta, keys)
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
  import Kalevala.Character.Conn

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

  def in_combat?(conn) when is_struct(conn, Kalevala.Character.Conn) do
    character = character(conn)
    character.meta.in_combat?
  end

  def in_combat?(%Kalevala.Character{meta: %{in_combat?: in_combat?}}) do
    in_combat?
  end

  def build_attack(conn, target) when not is_list(target) do
    build_attack(conn, List.wrap(target))
  end

  def build_attack(_conn, targets) do
    %CombatRequest{
      round_based?: true,
      victims: targets,
      target_count: 1,
      hitroll: 4,
      verb: "punch",
      speed: 1,
      damages: [
        %DamageSource{
          type: :blunt,
          damroll: Enum.random(1..8)
        }
      ],
      effects: []
    }
  end
end

defmodule Mu.Character.NonPlayerFlags do
  @derive Jason.Encoder

  @moduledoc """
  Booleans related to non-players only

  - sentinel? : True if the mob can leave the room
  - pursuer? : True if the mob will hunt fleeing players (overriden by sentinel)
  - aggressive? : True if mob will attack players without provocation
  """

  defstruct [
    :sentinel?,
    :pursuer?,
    :aggressive?
  ]
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
