defmodule Mu.Character.CombatAction do
  use Kalevala.Character.Action

  alias Mu.Character

  @impl true
  def run(conn, params) do
    params = Character.build_attack(params.text)

    Enum.reduce(1..1, conn, fn _, acc ->
      event(acc, "combat/request", params)
    end)
  end
end

defmodule Mu.Character.AutoAttackAction do
  use Kalevala.Character.Action

  alias Mu.Character

  @round_length_ms_less_500 2500

  def run(conn, %{target: target}) do
    character = character(conn)

    case can_attack?(character) do
      true ->
        now = Time.utc_now()
        now_in_ms = now.second * 1000 + div(elem(now.microsecond, 0), 1000)

        delay = @round_length_ms_less_500 - rem(now_in_ms, @round_length_ms_less_500)

        data = Character.build_attack(target)
        delay_event(conn, delay, "round/push", data)

      false ->
        conn
    end
  end

  defp can_attack?(character) do
    character.meta.vitals.health_points > 0
  end
end
