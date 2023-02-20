defmodule Mu.World.Room.CommunicationEvent do
  @moduledoc """
  Room events dealing with communication
  """
  import Kalevala.World.Room.Context

  def say(context, event) do
    name = event.data["at"]
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
    character = find_local_character(context, name) || find_player_character(name)
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
      reverse_find_local_exit(context, event.data.from_id)
      |> get_exit_name()

    data =
      event.data
      |> Map.put(:room_exits, room_exits)
      |> Map.put(:from_id, context.data.id)
      |> Map.put(:steps, [exit_name | event.data.steps])

    context
    |> event(event.from_pid, self(), event.topic, data)
  end

  defp get_exit_name(room_exit) do
    case !is_nil(room_exit) do
      true -> Map.get(room_exit, :exit_name, "nowhere")
      false -> "nowhere"
    end
  end

  defp reverse_find_local_exit(context, end_room_id) do
    Enum.find(context.data.exits, fn room_exit ->
      room_exit.end_room_id == end_room_id
    end)
  end

  defp find_player_character(name) do
    characters = Mu.Character.Presence.characters()
    find_character(characters, name)
  end

  defp find_local_character(context, name) do
    find_character(context.characters, name)
  end

  defp find_character(characters, name) do
    Enum.find(characters, fn character ->
      Kalevala.Character.matches?(character, name)
    end)
  end
end