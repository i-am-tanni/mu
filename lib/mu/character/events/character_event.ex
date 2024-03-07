defmodule Mu.Character.CharacterEvent do
  use Kalevala.Character.Event

  def action_next(conn, %{data: %{id: id}}) do
    current_action = conn.character.meta.processing_action

    case (current_action && current_action.id) == id do
      true -> Mu.Character.Action.progress(conn, current_action)
      false -> conn
    end
  end
end
