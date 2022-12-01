defmodule Mu.Character.Commands do
  @moduledoc false

  use Kalevala.Character.Command.Router, scope: Mu.Character

  module(LookCommand) do
    parse("look", :run, aliases: ["l"])
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
    parse("north", :north, aliases: ["n"])
    parse("south", :south, aliases: ["s"])
    parse("east", :east, aliases: ["e"])
    parse("west", :west, aliases: ["w"])
    # parse("up", :up, aliases: ["u"])
    # parse("down", :down, aliases: ["d"])
    # parse("northwest", :northwest, aliases: ["nw", "nwest"])
    # parse("northeast", :northeast, aliases: ["ne", "neast"])
    # parse("southwest", :southwest, aliases: ["sw", "swest"])
    # parse("southeast", :southeast, aliases: ["se", "seast"])
    # parse("in", :in)
    # parse("out", :out)
  end

  module(QuitCommand) do
    parse("quit", :run, aliases: ["q"])
  end
end
