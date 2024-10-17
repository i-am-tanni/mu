defmodule Mu.World.Room.LookEvent do
  import Kalevala.World.Room.Context
  import Mu.Utility

  require Logger

  alias Mu.Character.LookView
  alias Mu.World.Items
  alias Mu.World.Item
  alias Mu.World.Exit
  alias Mu.Character.CommandView
  alias Mu.World.Room
  alias Mu.World.WorldMap

  def call(context, event) do
    characters =
      Enum.reject(context.characters, fn character ->
        character.id == event.acting_character.id
      end)

    item_instances =
      Enum.map(context.item_instances, fn item_instance ->
        %{item_instance | item: Items.get!(item_instance.item_id)}
      end)

    room = context.data

    context
    |> assign(:room, room)
    |> assign(:mini_map, WorldMap.mini_map(room.id))
    |> assign(:characters, characters)
    |> assign(:item_instances, item_instances)
    |> assign(:self, event.acting_character)
    |> render(event.from_pid, LookView, "look")
    |> render(event.from_pid, LookView, "look.extra")
    |> prompt(event.from_pid, CommandView, "prompt")
  end

  def arg(context, event = %{data: %{text: text}}) do
    result =
      cond do
        result = find_local_exit(context, text) -> {:room_exit, result}
        result = find_local_character(context, text) -> {:character, result}
        result = find_local_item(context, text) -> {:item, result}
        result = find_local_extra_desc(context, text) -> {:extra_desc, result}
        true -> :not_found
      end

    case result do
      {:room_exit, room_exit} ->
        data =
          event.data
          |> Map.put(:distance, event.data.max_distance)
          |> Map.put(:result, [])

        event = %{event | data: data}

        context
        |> propagate_or_render(room_exit, event)

      {:character, character} ->
        context
        |> assign(:character, character)
        |> assign(:self, event.acting_character)
        |> render(event.from_pid, LookView, "character")
        |> render(event.from_pid, CommandView, "prompt")

      {:item, item_instance} ->
        context
        |> assign(:item_instance, item_instance)
        |> assign(:self, event.acting_character)
        |> render(event.from_pid, LookView, "item")
        |> render(event.from_pid, CommandView, "prompt")

      {:extra_desc, extra_desc} ->
        context
        |> assign(:extra_desc, extra_desc)
        |> assign(:self, event.acting_character)
        |> render(event.from_pid, LookView, "extra_desc")
        |> render(event.from_pid, CommandView, "prompt")

      :not_found ->
        context
        |> assign(:text, text)
        |> assign(:self, event.acting_character)
        |> render(event.from_pid, LookView, "unknown")
        |> render(event.from_pid, CommandView, "prompt")
    end
  end

  def exits(context, event) do
    context
    |> assign(:room, context.data)
    |> assign(:self, event.acting_character)
    |> render(event.from_pid, LookView, "exits")
    |> render(event.from_pid, CommandView, "prompt")
  end

  @doc """
  Event topic "peek/room"
  Look event propagated from another room. Peeks into neighboring rooms.
  Either continues propagation or returns result back to the acting_character.
  """
  def peek_room(context, event) do
    room_data = %{
      characters: context.characters,
      name: context.data.name,
      distance: countdown_to_countup(event.data.max_distance, event.data.distance, 1)
    }

    result = [room_data | event.data.result]

    distance = event.data.distance - 1

    room_exit = find_local_exit(context, event.data.text)

    case maybe(room_exit) do
      {:ok, room_exit} when distance > 0 ->
        data = %{event.data | distance: distance, result: result}
        event = %{event | data: data}

        context
        |> propagate_or_render(room_exit, event)

      _ ->
        context
        |> assign(:rooms, result)
        |> assign(:self, event.acting_character)
        |> render(event.from_pid, LookView, "peek-exit")
        |> render(event.from_pid, CommandView, "prompt")
    end
  end

  defp countdown_to_countup(max_count, i, count_from), do: max_count + count_from - i

  # propagates a look into another room
  defp propagate_or_render(context, room_exit, event) do
    # TODO: if door.closed? and !transparent, look at door description instead
    case room_exit do
      _ ->
        event = %{event | topic: "peek/room"}

        context
        |> pass(room_exit, event)
    end
  end

  defp pass(context, room_exit, event) do
    result = Room.whereis(room_exit.end_room_id)

    case maybe(result) do
      {:ok, end_room_pid} -> send(end_room_pid, event)
      nil -> Logger.error("Cannot find room #{room_exit.end_room_id}")
    end

    context
  end

  defp find_local_exit(context, name) do
    Enum.find(context.data.exits, fn room_exit ->
      Exit.matches?(room_exit, name)
    end)
  end

  defp find_local_character(context, name) do
    Enum.find(context.characters, fn character ->
      Mu.Character.matches?(character, name)
    end)
  end

  defp find_local_item(context, keyword) do
    Enum.find(context.item_instances, fn item_instance ->
      item = Items.get!(item_instance.item_id)
      Item.matches?(item, keyword)
    end)
  end

  defp find_local_extra_desc(context, keyword) do
    Enum.find(context.data.extra_descs, fn extra_desc ->
      keyword == extra_desc.keyword
    end)
  end

end
