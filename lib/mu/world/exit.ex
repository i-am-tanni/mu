defmodule Mu.World.Exit.Door do
  defstruct [:id, :closed?, :locked?]
end

defmodule Mu.World.Exit do
  @valid_exit_names ~w(north south east west up down)

  defstruct [
    :id,
    :type,
    :exit_name,
    :start_room_id,
    :end_room_id,
    :end_template_id,
    :door,
    :hidden?,
    :secret?
    ]

  def matches?(room_exit, keyword) do
    room_exit.id == keyword || keyword_match?(room_exit.exit_name, keyword)
  end

  def new(exit_name, start_room_id, end_room_id, end_template_id) do
    %__MODULE__{
      id: exit_name,
      type: :normal,
      exit_name: exit_name,
      start_room_id: start_room_id,
      end_template_id: end_template_id,
      end_room_id: end_room_id,
      hidden?: false,
      secret?: false,
      door: nil
    }
  end

  def sort(exits), do: Enum.sort(exits, & exit_sort_order(&1) < exit_sort_order(&2))

  def valid?(exit_name), do: exit_name in @valid_exit_names

  def to_long(exit_name) when byte_size(exit_name) == 1 do
    case exit_name do
      "n" -> "north"
      "s" -> "south"
      "e" -> "east"
      "w" -> "west"
      "u" -> "up"
      "d" -> "down"
      _ -> exit_name
    end
  end

  def to_long(exit_name) when byte_size(exit_name) == 2 do
    case exit_name do
      "nw" -> "northwest"
      "ne" -> "northeast"
      "sw" -> "southwest"
      "se" -> "southeast"
      _ -> exit_name
    end
  end

  def to_long(exit_name), do: exit_name

  def opposite(exit_name) do
    case exit_name do
      "north" -> "south"
      "south" -> "north"
      "east" -> "west"
      "west" -> "east"
      "up" -> "down"
      "down" -> "up"
      _ -> nil
    end
  end

  defp exit_sort_order(%{exit_name: exit_name}) do
    case exit_name do
      "north"     -> 0
      "northeast" -> 1
      "east"      -> 2
      "southeast" -> 3
      "south"     -> 4
      "southwest" -> 5
      "west"      -> 6
      "northwest" -> 7
      "up"        -> 8
      "down"      -> 9
      _           -> 10
    end
  end

  defp keyword_match?(exit_name, keyword) when is_binary(keyword) do
    exit_name = String.downcase(exit_name)
    keyword = String.downcase(keyword)
    exit_name == keyword || exit_name == exit_alias(keyword)
  end

  defp keyword_match?(_, _), do: false

  defp exit_alias(keyword) do
    case keyword do
      "n" -> "north"
      "s" -> "south"
      "e" -> "east"
      "w" -> "west"
      _ -> false
    end
  end
end
