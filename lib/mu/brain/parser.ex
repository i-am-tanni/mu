defmodule Mu.Brain.Parser.Helpers do
  @moduledoc false
  @doc """
  define a parser combinator and variable with same name
  """
  defmacro defcv(name, expr) do
    quote do
      defcombinatorp(unquote(name), unquote(expr))
      Kernel.var!(unquote({name, [], nil})) = parsec(unquote(name))
      _ = Kernel.var!(unquote({name, [], nil}))
    end
  end
end

defmodule Mu.Brain.Parser do
  @moduledoc """
  Parses a .brain file format into maps to be processed by Mu.Brain.parse_node()
  """

  import NimbleParsec
  import Mu.Brain.Parser.Helpers

  defcv(:skip, ascii_char([?\s, ?\n]) |> repeat() |> ignore())
  defcv(:lbrace, string("{") |> concat(skip) |> ignore())
  defcv(:rbrace, string("}") |> concat(skip) |> ignore())
  defcv(:lparen, string("(") |> concat(skip) |> ignore())
  defcv(:rparen, string(")") |> concat(skip) |> ignore())
  defcv(:colon, string(":") |> concat(skip) |> ignore())
  defcv(:comma, string(",") |> concat(skip) |> ignore())
  defcv(:int, integer(min: 1))

  defcv(
    :stringliteral,
    ignore(string(~s(")))
    |> utf8_string([not: ?"], min: 1)
    |> ignore(string(~s(")))
    |> concat(skip)
  )

  defcv(
    :quoted_word,
    ignore(string(~s(")))
    |> utf8_string([not: ?", not: ?\n, not: ?\s], min: 1)
    |> ignore(string(~s(")))
    |> concat(skip)
  )

  defcv(
    :boolean,
    choice([string("true") |> replace(true), string("false") |> replace(false)])
  )

  defcv(
    :key,
    utf8_string([not: ?:, not: ?=, not: ?\n, not: ?\s], min: 1)
    |> concat(colon)
  )

  defcv(
    :val,
    choice([stringliteral, boolean, int, parsec(:hashmap), parsec(:struct)])
    |> optional(comma)
  )

  defcv(
    :key_val,
    key
    |> concat(val)
    |> choice([skip, comma])
    |> wrap()
    |> map({List, :to_tuple, []})
  )

  defcv(
    :hashmap,
    lbrace
    |> repeat(key_val)
    |> concat(rbrace)
    |> wrap()
    |> map({Enum, :into, [%{}]})
    |> label("hash map: expected { followed by key_vals followed by }")
  )

  defcv(
    :struct,
    utf8_string([not: ?{, not: ?\n, not: ?\s], min: 1)
    |> unwrap_and_tag(:node)
    |> concat(hashmap)
    |> wrap()
    |> map({:merge, []})
  )

  defcv(
    :selector,
    utf8_string([not: ?(, not: ?\n, not: ?\s], min: 1)
    |> unwrap_and_tag(:node)
    |> concat(lparen)
    |> repeat(parsec(:node))
    |> concat(rparen)
    |> wrap()
    |> map({:package_selector, []})
  )

  defcv(
    :node,
    choice([struct, selector])
    |> optional(comma)
  )

  defcv(
    :brain,
    skip
    |> ignore(string("brain"))
    |> concat(lparen)
    |> concat(quoted_word)
    |> concat(rparen)
    |> concat(lbrace)
    |> repeat(node)
    |> concat(rbrace)
    |> wrap()
    |> map({List, :to_tuple, []})
  )

  defparsec(
    :parse,
    repeat(brain)
  )

  defp merge([{key, val}, map = %{}]), do: Map.put(map, key, val)

  defp package_selector([{key, val} | t]), do: %{key => val, nodes: t}

  def run(data) do
    {:ok, result, remainder, _, _, _} = parse(data)
    result = Enum.into(result, %{})

    case remainder == "" do
      true ->
        result

      false ->
        raise "Brain parsing failed! Error found in input: #{inspect(remainder)}"
    end
  end
end
