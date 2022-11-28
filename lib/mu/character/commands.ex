defmodule Mu.Character.Commands do
  @moduledoc false

  use Kalevala.Character.Command.Router, scope: Mu.Character

  module(LookCommand) do
    parse("look", :run, aliases: ["l"])
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

  module(MoveCommand) do
    parse("north", :north, aliases: ["n"])
    parse("south", :south, aliases: ["s"])
    parse("east", :east, aliases: ["e"])
    parse("west", :west, aliases: ["w"])
    parse("up", :up, aliases: ["u"])
    parse("down", :down, aliases: ["d"])
  end

  module(QuitCommand) do
    parse("quit", :run, aliases: ["q"])
  end
end
