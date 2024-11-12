defmodule Mu.Character.AiCombatController.MoveEvent do
  @moduledoc """
  Special events that can (potentially) end combat and result in a controller (state) change

  Mirrors the Player version with the main difference of:
    - What controller to exit to (NonPlayerController)
    - Non-players can pursue fleeing characters
  """
  use Kalevala.Character.Event

  # State Transitions
  alias Mu.Character.HuntController
  alias Mu.Character.NonPlayerController
  # Clean up on transition
  alias Mu.Character.AiCombatController
  # Misc
  alias Mu.Character.AutoAttackAction
  alias Mu.Character.MoveView

  def commit(conn, %{data: event}) do
    conn
    |> event("combat/flee", %{victim: character(conn), exit_name: event.exit_name})
    |> prompt(MoveView, "flee")
  end

  # if self died
  def death_notice(conn, event) when conn.character.id == event.data.victim.id do
    conn
    |> Mu.Character.Action.cancel()
    |> move(:from, conn.character.room_id, MoveView, :suppress, %{})
    |> halt()
  end

  # else if someone else died
  def death_notice(conn, event) do
    dead_character_id = event.data.victim.id
    target_id = Map.get(get_meta(conn, :target), :id)

    foes =
      get_flash(conn, :foes)
      |> MapSet.delete(dead_character_id)

    conn = put_flash(conn, :foes, foes)
    threat_table = get_meta(conn, :threat_table)

    case dead_character_id == target_id do
      true ->
        case max_threat(threat_table, foes) do
          {:ok, next_target} -> switch_target(conn, next_target)
          :error -> put_controller_with_cleanup(conn, NonPlayerController)
        end

      false ->
        put_flash(conn, :foes, foes)
    end
  end

  def notice(conn, %{data: event}) when event.direction == :to do
    # character enters while non-player is in combat
    threat_table = get_meta(conn, :threat_table)
    acting_character_id = event.character.id

    case Map.has_key?(threat_table, acting_character_id) do
      true ->
        foes = get_flash(conn, :foes)
        foes = MapSet.put(foes, acting_character_id)
        put_flash(conn, :foes, foes)

      false ->
        conn
    end
  end

  # when character leaves the room while non-player is in combat
  def notice(conn, %{data: event}) when event.direction == :from do
    fleeing_character_id = event.character.id
    target_id = Map.get(get_meta(conn, :target), :id)

    # update foes in case acting character was a foe
    old_foes = get_flash(conn, :foes)
    new_foes = MapSet.delete(old_foes, fleeing_character_id)

    conn =
      case MapSet.member?(old_foes, fleeing_character_id) do
        true -> put_flash(conn, :foes, new_foes)
        false -> conn
      end

    threat_table = get_meta(conn, :threat_table)
    exit_name = event.data.to
    flags = get_meta(conn, :flags)

    # check if fleeing character is target
    case fleeing_character_id == target_id do
      # if pursuit is an option, hunt if fleeing character is max threat
      true when flags.pursuer? and not flags.sentinel? and exit_name != nil ->
        case max_threat(threat_table, old_foes) do
          {:ok, %{id: ^fleeing_character_id}} ->
            %{expires_at: expires_at} = threat_table[fleeing_character_id]

            hunt_data = %HuntController{
              target_id: fleeing_character_id,
              expires_at: expires_at,
              room_id: conn.character.room_id,
              return_path: [],
              initial_exit_name: exit_name
            }

            put_controller_with_cleanup(conn, HuntController, hunt_data)

          {:ok, next_target} ->
            # otherwise target max threat
            switch_target(conn, next_target)

          :error ->
            put_controller_with_cleanup(conn, NonPlayerController)
        end

      true ->
        # If the target fled and cannot pursue...
        case max_threat(threat_table, new_foes) do
          {:ok, next_target} -> switch_target(conn, next_target)
          :error -> put_controller_with_cleanup(conn, NonPlayerController)
        end

      false ->
        conn
    end
  end

  def abort(conn, _) do
    case get_meta(conn, :pose) do
      :pos_fighting -> conn
      _ -> put_meta(conn, :pose, :pos_fighting)
    end
  end

  defp max_threat(threat_table, foes) do
    max_threat =
      threat_table
      |> Map.values()
      |> Enum.filter(fn %{character: %{id: id}} ->
        MapSet.member?(foes, id)
      end)
      |> Enum.max_by(& &1.value, fn -> nil end)

    case max_threat do
      %{character: character} ->
        {:ok, character}

      nil ->
        # no threats remaining
        :error
    end
  end

  defp switch_target(conn, next_target) do
    conn
    |> put_meta(:target, next_target)
    |> event("round/cancel", %{})
    |> AutoAttackAction.run(%{target: next_target.id})
  end

  defp put_controller_with_cleanup(conn, controller, flash \\ %{}) do
    conn
    |> AiCombatController.terminate()
    |> put_controller(controller, flash)
  end
end

defmodule Mu.Character.NonPlayerCombatEvents do
  @moduledoc """
  Special events that can result in a state change (MoveEvent)
  and/or are exclusive to this controller (CombatEvent)
  """
  use Kalevala.Event.Router

  alias Kalevala.Event.Movement

  scope(Mu.Character.AiCombatController) do
    module(MoveEvent) do
      event(Movement.Commit, :commit)
      event(Movement.Notice, :notice)
      event(Movement.Abort, :abort)
      event("death", :death_notice)
    end
  end
end

defmodule Mu.Character.AiCombatController do
  @moduledoc """
  Controller for non-players to fight
  """

  use Kalevala.Character.Controller

  alias Mu.Character.NonPlayerCombatEvents

  alias Mu.Character.AutoAttackAction
  alias Mu.Character.NonPlayerEvents

  @impl true
  def init(conn) do
    character = character(conn)
    AutoAttackAction.run(conn, %{target: character.meta.target.id})
  end

  @impl true
  def event(conn, event) do
    IO.inspect(event.topic, label: "event #{conn.character.id}")

    # conn.character.brain
    # |> Brain.run(conn, event)
    conn
    |> NonPlayerCombatEvents.call(event)
    |> NonPlayerEvents.call(event)
  end

  @impl true
  def recv(conn, _), do: conn

  @impl true
  def display(conn, _text), do: conn

  def terminate(conn) do
    character = character(conn)
    meta = %{character.meta | in_combat?: false, pose: :pos_standing, target: nil}
    put_character(conn, %{character | meta: meta})
  end
end
