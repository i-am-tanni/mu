defmodule Mu.Character.ContinueEvent do
  use Kalevala.Character.Event

  def action_next(conn, _event) do
    current_action = conn.character.meta.processing_action

    case !is_nil(current_action) do
      true -> Mu.Character.Action.progress(conn, current_action)
      false -> conn
    end
  end
end
