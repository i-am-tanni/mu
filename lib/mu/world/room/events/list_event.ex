defmodule Mu.World.Room.ListEvent do
  @moduledoc """
  Lists information for non-player characters gathered from the local room
  """
  import Kalevala.World.Room.Context

  def characters(context, event) do
    character_ids = Enum.map(context.characters, & &1.id)
    event(context, event.from_pid, self(), event.topic, %{characters: character_ids})
  end
end
