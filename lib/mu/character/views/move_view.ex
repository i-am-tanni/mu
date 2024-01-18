defmodule Mu.Character.MoveView do
  use Kalevala.Character.View

  alias Mu.Character.CharacterView

  def render(:suppress, _assigns), do: []

  def render("enter", %{character: character, from: entrance_name}) do
    enter_string =
      case character.meta.mode do
        :combat -> "flees"
        _ -> "enters"
      end

    ~i(#{CharacterView.render("name", %{character: character})} #{enter_string} from the #{entrance_name}.)
  end

  def render("leave", %{character: character, to: exit_name}) do
    leave_string =
      case character.meta.mode do
        :combat -> "flees"
        _ -> "leaves"
      end

    ~i(#{CharacterView.render("name", %{character: character})} #{leave_string} #{exit_name}.)
  end

  def render("respawn", %{character: character}) do
    ~i(#{CharacterView.render("name", %{character: character})} fades into existence.)
  end

  def render("notice", %{direction: :to, reason: reason}) do
    [reason, "\n"]
  end

  def render("notice", %{direction: :from, reason: reason}) do
    [reason, "\n"]
  end

  def render("fail", %{reason: "no-exits"}) do
    ~i(You diligently search for an exit, but fail to find one.\n)
  end

  def render("fail", %{reason: :no_exit, exit_name: exit_name}) do
    ~i(There is no exit #{exit_name}.\n)
  end

  def render("fail", %{reason: :door_locked, exit_name: exit_name}) do
    ~i(The door #{exit_name} is closed and locked.\n)
  end

  def render("fail", %{reason: :door_closed, exit_name: exit_name}) do
    ~i(The door #{exit_name} is closed.\n)
  end
end
