defmodule Mu.Character.CommandController.PreParser do
  import NimbleParsec

  word = utf8_string([not: ?\s, not: ?\r, not: ?\n, not: ?\t, not: ?\d], min: 1)
  ignore_white_space = ignore(repeat(utf8_char([?\s, ?\r, ?\n, ?\t, ?\d])))

  command =
    optional(ignore_white_space)
    |> concat(word)
    |> map({String, :downcase, []})
    |> map({:substitute_alias, []})

  defparsec(:run, command)

  def substitute_alias(verb) do
    IO.inspect(verb)

    case verb do
      "=" -> "ooc"
      _ -> verb
    end
  end
end

defmodule Foo do
  alias Mu.Character.CommandController.PreParser

  def pre_parse(text) do
    {:ok, [command], text, _, _, _} = PreParser.run(text)
    command <> String.downcase(text)
  end
end
