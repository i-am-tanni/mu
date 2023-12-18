defmodule Mu.Character.CombatView do
  use Kalevala.Character.View

  alias Mu.Character.CharacterView

  def render("kickoff/attacker", %{victim: victim}) do
    ~i(You attack #{CharacterView.render("name", %{character: victim})}!\n)
  end

  def render("kickoff/victim", %{attacker: attacker}) do
    ~i(#{CharacterView.render("name", %{character: attacker})} attacks you!\n)
  end

  def render("kickoff/witness", %{attacker: attacker, victim: victim}) do
    attacker = CharacterView.render("name", %{character: attacker})
    victim = CharacterView.render("name", %{character: victim})
    ~i(#{attacker} attacks #{victim}!\n)
  end

  def render("damage/attacker", assigns) do
    victim = CharacterView.render("name", %{character: assigns.victim})
    feedback = damage_feedback(assigns)
    ~i(Your #{assigns.verb} #{feedback} #{victim}! \(#{assigns.damage}\)\n)
  end

  def render("damage/victim", assigns) do
    attacker = CharacterView.render("name-possessive", %{character: assigns.attacker})
    feedback = damage_feedback(assigns)
    ~i(#{attacker} #{assigns.verb} #{feedback} you!\n)
  end

  def render("damage/witness", assigns) do
    attacker = CharacterView.render("name-possessive", %{character: assigns.attacker})
    victim = CharacterView.render("name", %{character: assigns.victim})
    feedback = damage_feedback(assigns)

    ~i(#{attacker} #{assigns.verb} #{feedback} #{victim}! \(#{assigns.damage}\)\n)
  end

  def render("miss/attacker", assigns) do
    victim = CharacterView.render("name", %{character: assigns.victim})
    ~i(Your #{assigns.verb} misses #{victim}.)
  end

  def render("miss/victim", assigns) do
    attacker = CharacterView.render("name", %{character: assigns.attacker})
    ~i(#{attacker} #{assigns.verb} misses you.)
  end

  def render("miss/witness", assigns) do
    attacker = CharacterView.render("name", %{character: assigns.attacker})
    victim = CharacterView.render("name", %{character: assigns.victim})

    ~i(#{attacker} #{assigns.verb} misses #{victim}.\n)
  end

  def render("death/witness", %{attacker: attacker, victim: victim, death_cry: death_cry}) do
    attacker = CharacterView.render("name", %{character: attacker})
    victim = CharacterView.render("name", %{character: victim})

    [~i(#{victim} #{death_cry}!\n), ~i(#{attacker} kills #{victim}!)]
  end

  def render("death/victim", assigns) do
    attacker = CharacterView.render("name", %{character: assigns.attacker})
    [~i(#{attacker} has killed you!\n), ~i(You are DEAD!!!)]
  end

  def render("death/attacker", %{victim: victim, death_cry: death_cry}) do
    victim = CharacterView.render("name", %{character: victim})
    [~i(#{victim} #{death_cry}!\n), ~i(You have killed #{victim}!)]
  end

  def render("error", %{reason: reason}) do
    case reason do
      "pvp" -> ~i(Player vs player combat isn't allowed.\n)
      "already-fighting" -> ~i(You are already fighting!\n)
      "peaceful" -> ~i(Violence is not allowed here.\n)
      "combat/over" -> ~i(You've already won the fight!\n)
      "not-in-combat" -> ~i(You aren't in combat. Use the kill command to start combat.\n)
    end
  end

  defp damage_feedback(%{victim: victim, damage: damage}) do
    max_health_points = victim.meta.vitals.max_health_points
    dam_percent = div(damage * 100, max_health_points)

    cond do
      dam_percent <= 0 -> "misses"
      dam_percent <= 1 -> "tickles"
      dam_percent <= 2 -> "nicks"
      dam_percent <= 3 -> "scuffs"
      dam_percent <= 4 -> "bruises"
      dam_percent <= 5 -> "scratches"
      dam_percent <= 10 -> "grazes"
      dam_percent <= 15 -> "injures"
      dam_percent <= 20 -> "wounds"
      dam_percent <= 25 -> "mauls"
      dam_percent <= 30 -> "maims"
      dam_percent <= 35 -> "mangles"
      dam_percent <= 40 -> "decimates"
      dam_percent <= 45 -> "mutilates"
      dam_percent <= 50 -> "wrecks"
      dam_percent <= 55 -> "RAVAGES"
      dam_percent <= 60 -> "TRAUMATIZES"
      dam_percent <= 65 -> "CRIPPLES"
      dam_percent <= 70 -> "MASSACRES"
      dam_percent <= 75 -> "DEMOLISHES"
      dam_percent <= 80 -> "DEVASTATES"
      dam_percent <= 85 -> "PULVERIZES"
      dam_percent <= 90 -> "OBLITERATES"
      dam_percent <= 95 -> "ANNHILATES"
      dam_percent <= 100 -> "ERADICATES"
      dam_percent <= 200 -> "SLAUGHTERS"
      dam_percent <= 300 -> "LIQUIFIES"
      dam_percent <= 400 -> "VAPORIZES"
      dam_percent <= 500 -> "ATOMIZES"
      dam_percent > 500 -> "does UNSPEAKABLE things to"
    end
  end

  defp conjugate(verb) do
    cond do
      Regex.match?(~r/o$/, verb) -> [verb, "es"]
      Regex.match?(~r/ch$/, verb) -> [verb, "es"]
      Regex.match?(~r/ss$/, verb) -> [verb, "es"]
      Regex.match?(~r/sh$/, verb) -> [verb, "es"]
      Regex.match?(~r/x$/, verb) -> [verb, "es"]
      head = Regex.run(~r/\w+[^aeiou](?=y$)/, verb) -> [head, "ies"]
      true -> [verb, "s"]
    end
  end
end
