defmodule Mu.Character.CombatController.MoveEvent do
  @moduledoc """
  Special events that can (potentially) end combat and result in a controller (state) change
  Or should be otherwise be performed in addition to the standard MoveEvent
  """
  use Kalevala.Character.Event

  alias Mu.Character.MoveView
  alias Mu.Character.CombatController
  alias Mu.Character.CommandController

  alias Mu.Character.AutoAttackAction

  def commit(conn, %{data: event}) do
    conn
    |> event("combat/flee", %{victim: character(conn), exit_name: event.exit_name})
    |> prompt(MoveView, "flee")
  end

  def death_notice(conn, event) when conn.character.id == event.data.victim.id do
    vitals = get_meta(conn, :vitals)
    vitals = %{vitals | health_points: vitals.max_health_points}

    conn
    |> Mu.Character.Action.stop()
    |> put_meta(:threat_table, %{})
    |> put_meta(:vitals, vitals)
  end

  def death_notice(conn, event) do
    handle_departure(conn, event.data.victim.id)
  end

  def notice(conn, %{data: event}) when event.direction == :from do
    handle_departure(conn, event.character.id)
  end

  def notice(conn, %{data: event}) when event.direction == :to do
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

  defp handle_departure(conn, acting_character_id) do
    target_id = Map.get(get_meta(conn, :target), :id)

    foes =
      get_flash(conn, :foes)
      |> MapSet.delete(acting_character_id)

    conn = put_flash(conn, :foes, foes)

    case acting_character_id == target_id do
      true ->
        threat_table = get_meta(conn, :threat_table)

        case max_threat(threat_table, foes) do
          {:ok, next_target} ->
            conn
            |> put_meta(:target, next_target)
            |> event("round/cancel", %{})
            |> AutoAttackAction.run(%{target: next_target.id})

          :error ->
            conn
            |> CombatController.terminate()
            |> put_controller(CommandController, %{})
        end

      false ->
        conn
    end
  end

  defp max_threat(threat_table, foes) do
    threats =
      threat_table
      |> Map.values()
      |> Enum.filter(fn %{character: %{id: id}} ->
        MapSet.member?(foes, id)
      end)

    case !Enum.empty?(threats) do
      true ->
        max_threat =
          threats
          |> Enum.max_by(& &1.value)
          |> Map.get(:character)

        {:ok, max_threat}

      false ->
        :error
    end
  end
end

defmodule Mu.Character.CombatEvents do
  @moduledoc """
  Special events that:
    - can result in a controller change
    - modify flash data local to the controller
    - are exclusive to the controller
    - or are performed in addition to the standard event routed in Mu.Character.Events
  """
  use Kalevala.Event.Router

  alias Kalevala.Event.Movement

  scope(Mu.Character.CombatController) do
    module(MoveEvent) do
      # event("combat/abort", :abort) check if character crashed and is missing
      event(Movement.Commit, :commit)
      event(Movement.Notice, :notice)
      event(Movement.Abort, :abort)
      event("death", :death_notice)
    end
  end
end

defmodule Mu.Character.CombatController do
  @moduledoc """
  Controller for players to fight
  """

  use Kalevala.Character.Controller

  alias Mu.Character.Events
  alias Mu.Character.CombatEvents
  alias Mu.Character.AutoAttackAction
  alias Mu.Character.CommandController

  @impl true
  def init(conn) do
    character = character(conn)
    AutoAttackAction.run(conn, %{target: character.meta.target.id})
  end

  @impl true
  def event(conn, event) do
    IO.inspect(event.topic, label: "event #{conn.character.id}")

    conn
    |> CombatEvents.call(event)
    |> Events.call(event)
  end

  @impl true
  defdelegate recv(conn, data), to: CommandController

  @impl true
  defdelegate recv_event(conn, event), to: CommandController

  def terminate(conn) do
    character = character(conn)
    meta = %{character.meta | in_combat?: false, pose: :pos_standing, target: nil}
    put_character(conn, %{character | meta: meta})
  end
end
