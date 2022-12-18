defmodule Mu.World.Exit do
  defstruct [:id, :exit_name, :start_room_id, :end_room_id, :door, :hidden?, :secret?]

  def matches?(room_exit, keyword) do
    room_exit.id == keyword || keyword_match?(room_exit.exit_name, keyword)
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

defmodule Mu.World.Exit.Door do
  defstruct [:id, :closed?, :locked?]
end
