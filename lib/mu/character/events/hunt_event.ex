defmodule Mu.Character.HuntEvent do
  @moduledoc """
  For Non-players hunting characters
  Callable via the HuntController, which is used by non-players only
  """

  use Kalevala.Character.Event
  import Mu.Character.Guards
  import Mu.Utility

  alias Mu.Character
  alias Mu.Character.PathController

  # Actions
  alias Mu.Character.WanderAction
  alias Mu.Character.ListAction
  alias Mu.Character.CombatAction

  def call(conn, event) when not in_combat(conn) do
    target_id = get_flash(conn, :target_id)
    expires_at = get_flash(conn, :expires_at)

    # As long as the hunt hasn't expired
    case Time.compare(Time.utc_now(), expires_at) == :lt do
      true ->
        # If quarry is in the room
        result = Enum.find(event.data.characters, &(&1 == target_id))

        case maybe(result) do
          # attack
          {:ok, target} ->
            attack_data = Character.build_attack(conn, target)
            CombatAction.put(conn, attack_data)

          # ...or continue hunting
          nil ->
            conn
            |> WanderAction.put(%{}, pre_delay: 3000)
            |> ListAction.put(%{type: :characters})
        end

      false ->
        # but if expired, path home
        threat_table = get_meta(conn, :threat_table)
        return_path = get_flash(conn, :return_path)
        destination = get_flash(conn, :room_id)

        data = %PathController{
          path: return_path,
          destination_id: destination
        }

        conn
        |> put_meta(:threat_table, refresh(threat_table))
        |> put_controller(PathController, data)
    end
  end

  def call(conn, _), do: conn

  defp refresh(threat_table) do
    threat_table
    |> Enum.filter(fn {_, %{expires_at: expires_at}} ->
      Time.compare(Time.utc_now(), expires_at) == :lt
    end)
    |> Enum.into(%{})
  end
end
