defmodule Mu.Character.Commands.Helpers do
  import NimbleParsec

  @moduledoc """
  Helper parsers for commands
  """

  def text_not(stop, tag) do
    repeat(
      lookahead_not(stop)
      |> utf8_char([])
    )
    |> optional(ignore(stop))
    |> reduce({List, :to_string, []})
    |> post_traverse({Kalevala.Character.Command.RouterHelpers, :trim, []})
    |> unwrap_and_tag(tag)
  end

  @doc """
  Specifies which item in the list is required
  """
  def dot_ordinal(tag \\ "") do
    tag = reference(tag, "ordinal")

    number()
    |> ignore(string("."))
    |> unwrap_and_tag(tag)
  end

  @doc """
  Specifies how many items (plural) in the list are required
  """
  def star_ordinal(tag \\ "") do
    tag = reference(tag, "count")

    number()
    |> ignore(string("*"))
    |> unwrap_and_tag(tag)
  end

  @doc """
  Equivalent to a star ordinal with the maximum count allowed
  """
  def all() do
    ignore(string("all"))
    |> ignore(optional(choice([string("."), spaces()])))
    |> replace(9999)
    |> unwrap_and_tag("count")
  end

  defp reference(tag_parent, tag_child, delim \\ "/") do
    case tag_parent != "" do
      true -> "#{tag_parent}#{delim}#{tag_child}"
      false -> tag_child
    end
  end

  defp number() do
    choice([positive_integer(), negative_integer()])
  end

  defp spaces() do
    times(utf8_char([?\s, ?\r, ?\n, ?\t, ?\d]), 1)
  end

  # used instead of integer() to avoid error on parser match failure
  defp positive_integer() do
    utf8_string([?0..?9], min: 1)
    |> map({String, :to_integer, []})
  end

  defp negative_integer() do
    ignore(string("-"))
    |> concat(positive_integer())
    |> map({:negate, []})
  end
end

defmodule Mu.Character.Commands do
  @moduledoc false

  use Kalevala.Character.Command.Router, scope: Mu.Character

  import Mu.Character.Commands.Helpers

  defp negate(n), do: n * -1

  module(BuildCommand) do
    parse("@dig", :dig, fn command ->
      command
      |> spaces()
      |> word(:start_exit_name)
      |> spaces()
      |> word(:end_exit_name)
      |> spaces()
      |> word(:new_room_id)
    end)
  end

  module(EmoteCommand) do
    parse("emote", :broadcast, fn command ->
      command |> spaces() |> text(:text)
    end)
  end

  module(ItemCommand) do
    parse("drop", :drop, fn command ->
      command
      |> spaces()
      |> optional(choice([all(), dot_ordinal(), star_ordinal()]))
      |> text(:item_name)
    end)

    parse("get", :get, fn command ->
      command
      |> spaces()
      |> optional(dot_ordinal("item"))
      |> concat(
        text_not(
          choice([
            string(" in "),
            string(" from ")
          ]),
          :item
        )
      )
      |> optional(
        optional(dot_ordinal("container"))
        |> text(:container_name)
      )
    end)

    parse("put", :put, fn command ->
      command
      |> spaces()
      |> optional(dot_ordinal("item"))
      |> concat(text_not(string(" in "), :item))
      |> optional(dot_ordinal("container"))
      |> text(:container)
    end)

    parse("wear", :wear, fn command ->
      command |> spaces() |> optional(dot_ordinal()) |> text(:item_name)
    end)

    parse("remove", :remove, fn command ->
      command |> spaces() |> optional(dot_ordinal()) |> text(:item_name)
    end)
  end

  module(InventoryCommand) do
    parse("inventory", :run, aliases: ["i"])
    parse("equipment", :equipment, aliases: ["eq"])
  end

  module(CombatCommand) do
    parse("kill", :request, fn command ->
      command |> spaces() |> text(:text)
    end)

    parse("attack", :attack, fn command ->
      command |> optional(spaces() |> text(:target))
    end)

    parse("flee", :flee, aliases: ["fle"])
  end

  module(LookCommand) do
    parse("look", :room, aliases: ["l"])

    parse("look", :run, fn command ->
      command |> spaces() |> text(:text)
    end)

    parse("exits", :exits, aliases: ["ex"])
  end

  module(DoorCommand) do
    parse("open", :run, fn command ->
      command |> spaces() |> text(:text)
    end)

    parse("close", :run, fn command ->
      command |> spaces() |> text(:text)
    end)
  end

  module(ReplyCommand) do
    parse("reply", :run, fn command ->
      command |> spaces() |> text(:text)
    end)
  end

  module(SayCommand) do
    parse("say", :run, fn command ->
      command
      |> spaces()
      |> optional(
        repeat(
          choice([
            symbol("@") |> word(:at) |> spaces(),
            symbol(">") |> word(:adverb) |> spaces()
          ])
        )
      )
      |> text(:text)
    end)
  end

  module(ChannelCommand) do
    parse("ooc", :ooc, fn command ->
      command |> spaces() |> text(:text)
    end)
  end

  module(TellCommand) do
    parse("tell", :run, fn command ->
      command
      |> spaces()
      |> word(:name)
      |> spaces()
      |> text(:text)
    end)
  end

  module(WhisperCommand) do
    parse("whisper", :run, fn command ->
      command
      |> spaces()
      |> word(:name)
      |> spaces()
      |> text(:text)
    end)
  end

  module(WhoCommand) do
    parse("who", :run)
  end

  module(MoveCommand) do
    parse("north", :run, aliases: ["n"])
    parse("south", :run, aliases: ["s"])
    parse("east", :run, aliases: ["e"])
    parse("west", :run, aliases: ["w"])
    # parse("up", :up, aliases: ["u"])
    # parse("down", :down, aliases: ["d"])
    # parse("northwest", :northwest, aliases: ["nw", "nwest"])
    # parse("northeast", :northeast, aliases: ["ne", "neast"])
    # parse("southwest", :southwest, aliases: ["sw", "swest"])
    # parse("southeast", :southeast, aliases: ["se", "seast"])
    # parse("in", :in)
    # parse("out", :out)
  end

  module(PathFindCommand) do
    parse("track", :track, fn command ->
      command |> spaces() |> text(:text)
    end)

    parse("yell", :yell, fn command ->
      command |> spaces() |> text(:text)
    end)
  end

  module(QuitCommand) do
    parse("quit", :run, aliases: ["q"])
  end

  module(RandomExitCommand) do
    parse("wander", :wander, aliases: ["wa"])
  end

  dynamic(SocialCommand, :social, [])
end
