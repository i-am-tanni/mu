defmodule Mu.Character.MoveView do
  use Kalevala.Character.View

  alias Mu.Character.CharacterView

  def render(:suppress, _assigns), do: []

  def render("enter", %{character: character, from: entrance_name}) do
    enter_string =
      case character.meta.pose do
        :pos_fighting -> "flees"
        _ -> "enters"
      end

    entrance_name = entrance_name || "somewhere"

    ~i(#{CharacterView.render("name", %{character: character})} #{enter_string} from the #{entrance_name}.)
  end

  def render("leave", %{character: character, to: exit_name}) do
    leave_string =
      case character.meta.pose do
        :pos_fighting -> "flees"
        _ -> "leaves"
      end

    ~i(#{CharacterView.render("name", %{character: character})} #{leave_string} #{exit_name}.)
  end

  def render("teleport/enter", %{character: character}) do
    ~i(#{CharacterView.render("name", %{character: character})} enters from a tear in interstitial space.)
  end

  def render("teleport/leave", %{character: character}) do
    ~i(#{CharacterView.render("name", %{character: character})} leaves in a tear of interstitial space.)
  end

  def render("flee", %{}) do
    ~i(You flee head over heels!)
  end

  def render("respawn", %{character: character}) do
    ~i(#{CharacterView.render("name", %{character: character})} fades into existence.)
  end

  def render("notice", %{direction: :to, reason: reason}) do
    [reason, "\r\n"]
  end

  def render("notice", %{direction: :from, reason: reason}) do
    [reason, "\r\n"]
  end

  def render("fail", %{reason: "no-exits"}) do
    ~i(You diligently search for an exit, but fail to find one.\r\n)
  end

  def render("fail", %{reason: :no_exit, exit_name: exit_name}) do
    ~i(There is no exit #{exit_name}.\r\n)
  end

  def render("fail", %{reason: :door_locked, exit_name: exit_name}) do
    ~i(The door #{exit_name} is closed and locked.\r\n)
  end

  def render("fail", %{reason: :door_closed, exit_name: exit_name}) do
    ~i(The door #{exit_name} is closed.\r\n)
  end
end
