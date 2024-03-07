defmodule Mu.World.Room.ListEvent do
  import Kalevala.World.Room.Context

  def characters(context, event) when event.data.type == :characters do
    character_ids = Enum.map(context.characters, & &1.id)
    event(context, event.from_pid, self(), event.topic, %{characters: character_ids})
  end
end
