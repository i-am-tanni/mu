defmodule Mu.Character.CombatAction do
  use Mu.Character.Action

  @impl true
  def run(conn, params) do
    event(conn, "combat/request", params)
  end

  @impl true
  def build(params, _opts \\ []) do
    %Action{
      type: __MODULE__,
      priority: 7,
      conditions: [:pos_standing],
      steps: [
        Action.step(__MODULE__, 250, params)
      ]
    }
  end
end

defmodule Mu.Character.AutoAttackAction do
  use Kalevala.Character.Action

  alias Mu.Character

  @round_length_ms_less_500 2500

  @impl true
  def run(conn, %{target: target}) do
    character = character(conn)

    case can_attack?(character) do
      true ->
        now = Time.utc_now()
        now_in_ms = now.second * 1000 + div(elem(now.microsecond, 0), 1000)

        delay = @round_length_ms_less_500 - rem(now_in_ms, @round_length_ms_less_500)

        data = Character.build_attack(conn, target)
        delay_event(conn, delay, "round/push", data)

      false ->
        conn
    end
  end

  defp can_attack?(character) do
    character.meta.vitals.health_points > 0 and
      character.meta.pose == :pos_fighting
  end
end
