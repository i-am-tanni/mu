defmodule Mu.Character.CommandView do
  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText

  def render("prompt", %{self: self}) do
    %{vitals: vitals} = self.meta

    %EventText{
      topic: "Character.Prompt",
      data: vitals,
      text: [
        "\r\n",
        "[",
        ~i({hp}#{vitals.health_points}/#{vitals.max_health_points}hp{/hp} ),
        ~i({sp}#{vitals.skill_points}/#{vitals.max_skill_points}sp{/sp} ),
        ~i({ep}#{vitals.endurance_points}/#{vitals.max_endurance_points}ep{/ep}),
        "] > "
      ]
    }
  end

  def render("error", %{reason: reason}) do
    reason
  end

  def render("unknown", _assigns) do
    "huh?\r\n"
  end
end
