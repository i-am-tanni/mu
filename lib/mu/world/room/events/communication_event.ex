defmodule Mu.World.Room.CommunicationEvent do
  @moduledoc """
  Room events dealing with communication
  """
  import Kalevala.World.Room.Context
  import Mu.Utility

  def say(context, event) do
    name = Map.fetch!(event.data, "at")
    character = find_local_character(context, name)
    data = Map.put(event.data, "at_character", character)
    event(context, event.from_pid, self(), event.topic, data)
  end

  def social(context, event) do
    name = event.data.name
    character = find_local_character(context, name)
    data = Map.put(event.data, :character, character)
    event(context, event.from_pid, self(), event.topic, data)
  end

  def tell(context, event) do
    name = event.data.name
    character = find_player_character(name)
    data = Map.put(event.data, :character, character)
    event(context, event.from_pid, self(), event.topic, data)
  end

  def whisper(context, event) do
    name = event.data.name
    character = find_local_character(context, name)
    data = Map.put(event.data, :character, character)
    event(context, event.from_pid, self(), event.topic, data)
  end

  def yell(context, event) do
    room_exits =
      context.data.exits
      |> Enum.map(fn room_exit ->
        %{room_id: room_exit.end_room_id}
      end)

    exit_name =
      case maybe(find_exit(context, event.data.from_id)) do
        {:ok, room_exit} -> Map.get(room_exit, :exit_name, "nowhere")
        nil -> "nowhere"
      end

    data =
      event.data
      |> Map.put(:room_exits, room_exits)
      |> Map.put(:from_id, context.data.id)
      |> Map.put(:steps, [exit_name | event.data.steps])

    context
    |> event(event.from_pid, self(), event.topic, data)
  end

  defp find_exit(context, end_room_id) do
    Enum.find(context.data.exits, fn room_exit ->
      room_exit.end_room_id == end_room_id
    end)
  end

  defp find_player_character(name) do
    Mu.Character.Presence.characters()
    |> Enum.find(&Mu.Character.matches?(&1, name))
  end

  defp find_local_character(context, name) do
    context.characters
    |> Enum.find(&Mu.Character.matches?(&1, name))
  end
end
