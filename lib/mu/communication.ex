defmodule Mu.Communication.BroadcastChannel do
  use Kalevala.Communication.Channel
end

defmodule Mu.Communication.Parser do
  import NimbleParsec

  text = utf8_string([], min: 1)
  ignore_white_space = ignore(repeat(utf8_char([?\s, ?\r, ?\n, ?\t, ?\d])))

  color_code =
    string("\e[")
    |> utf8_string([not: ?m], min: 1)
    |> string("m")

  ignore_escape_sequences = ignore(repeat(choice([color_code, string("\\")])))

  word = utf8_string([not: ?\s, not: ?\n, not: ?\\, not: ?\r, not: ?\t, not: ?\d], min: 1)

  comm_parser = times(choice([ignore_white_space, ignore_escape_sequences, word]), min: 1)

  defparsec(:parse, comm_parser)

  def run(text) do
    {:ok, result, _, _, _, _} = parse(text)
    [first_word, rest] = result
    first_word = capitalize(first_word)

    rest =
      case !is_question?(first_word) do
        true -> add_punctuation(rest, ".")
        false -> add_punctuation(rest, "?")
      end

    [first_word, rest] |> join(?\s)
  end

  defp capitalize(word) do
    {first_letter, rest} = String.next_grapheme(word)
    String.capitalize(first_letter) <> rest
  end

  defp add_punctuation(sentence, punctuation) do
    case List.last(sentence) in ~w(. ? !) do
      true -> sentence
      false -> [sentence, punctuation]
    end
  end

  defp is_question?(word) do
    String.downcase(word) in ~w(who what when where why which how whose)
  end

  defp join([], _separator), do: []

  defp join([line], _separator), do: [line]

  defp join([line, punctuation | lines], separator) when punctuation in ~w(" ' , . ? !) do
    [line, punctuation | join(lines, separator)]
  end

  defp join([line | lines], separator) do
    [line, separator | join(lines, separator)]
  end
end

defmodule Mu.Communication do
  @moduledoc false

  use Kalevala.Communication

  @impl true
  def initial_channels() do
    [{"ooc", Mu.Communication.BroadcastChannel, []}]
  end
end
