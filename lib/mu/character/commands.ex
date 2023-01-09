defmodule Mu.Character.Commands do
  @moduledoc false

  use Kalevala.Character.Command.Router, scope: Mu.Character

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
      command |> spaces() |> text(:item_name)
    end)

    parse("get", :get, fn command ->
      command |> spaces() |> text(:item_name)
    end)
  end

  module(InventoryCommand) do
    parse("inventory", :run, aliases: ["i"])
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
  end

  module(QuitCommand) do
    parse("quit", :run, aliases: ["q"])
  end

  module(RandomExitCommand) do
    parse("wander", :wander, aliases: ["wa"])
  end

  dynamic(SocialCommand, :social, [])
end
