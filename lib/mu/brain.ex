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
    choice([stringliteral, boolean, int, parsec(:hashmap)])
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

defmodule Mu.Brain.Action do
  @moduledoc """
  Node to trigger an action
  """

  defstruct [:data, :type, delay: 0]

  defimpl Kalevala.Brain.Node do
    alias Kalevala.Brain.Variable
    alias Kalevala.Character.Conn

    def run(node, conn, event) do
      character = Conn.character(conn, trim: true)
      event_data = Map.merge(Map.from_struct(character), event.data)

      case Variable.replace(node.data, event_data) do
        {:ok, data = %{type: callback_module, delay: pre_delay}} ->
          action = callback_module.put(conn, data)
          Mu.Character.Action.put(conn, action, pre_delay: pre_delay)

        :error ->
          conn
      end
    end
  end
end

defmodule Mu.Brain do
  @moduledoc """
  Load and parse brain data into behavior tree structs
  """

  @brains_path "data/brains"

  @doc """
  Load brain data from the path

  Defaults to `#{@brains_path}`
  """

  def read(data) do
    Mu.Brain.Parser.run(data)
  end

  def process_all(brains) do
    Enum.into(brains, %{}, fn {key, value} ->
      {key, process(value, brains)}
    end)
  end

  def process(brain, brains) when brain != nil do
    %Kalevala.Brain{
      root: parse_node(brain, brains)
    }
  end

  def process(_, _brains) do
    %Kalevala.Brain{
      root: %Kalevala.Brain.NullNode{}
    }
  end

  # References to other trees

  defp parse_node(node, brains), do: parse_node(node.node, node, brains)

  defp parse_node("Node", %{"ref" => ref}, brains) do
    parse_node(brains[ref], brains)
  end

  # Selectors

  defp parse_node("FirstSelector", %{nodes: nodes}, brains) do
    %Kalevala.Brain.FirstSelector{
      nodes: Enum.map(nodes, &parse_node(&1, brains))
    }
  end

  defp parse_node("ConditionalSelector", %{nodes: nodes}, brains) do
    %Kalevala.Brain.ConditionalSelector{
      nodes: Enum.map(nodes, &parse_node(&1, brains))
    }
  end

  defp parse_node("Sequence", %{nodes: nodes}, brains) do
    %Kalevala.Brain.Sequence{
      nodes: Enum.map(nodes, &parse_node(&1, brains))
    }
  end

  defp parse_node("RandomSelector", %{nodes: nodes}, brains) do
    %Kalevala.Brain.RandomSelector{
      nodes: Enum.map(nodes, &parse_node(&1, brains))
    }
  end

  # Conditions and Actions

  defp parse_node("MessageMatch", node, _brains) do
    %{"text" => text, "channel" => channel} = node
    {:ok, regex} = Regex.compile(text, "i")

    %Kalevala.Brain.Condition{
      type: Kalevala.Brain.Conditions.MessageMatch,
      data: %{
        interested?: channel_to_interested(channel),
        text: regex,
        self_trigger: node["self_trigger"] == true
      }
    }
  end

  defp parse_node("EventMatch", node, _brains) do
    data = Map.get(node, "data", %{})
    topic = Map.fetch!(node, "topic")

    with nil <- parse_condition(topic, data) do
      %Kalevala.Brain.Condition{
        type: Kalevala.Brain.Conditions.EventMatch,
        data: %{
          topic: topic,
          self_trigger: node["self_trigger"] == true,
          data: keys_to_atoms(data)
        }
      }
    end
  end

  defp parse_node("StateMatch", %{"match" => match}, _brains) do
    match = process_match(match)

    %Kalevala.Brain.Condition{
      type: Kalevala.Brain.Conditions.StateMatch,
      data: %{
        key: match.key,
        value: match.value,
        match: match.operator
      }
    }
  end

  defp parse_node("StateSet", node, _brains) do
    %Kalevala.Brain.StateSet{
      data: %{
        key: Map.fetch!(node, "key"),
        value: Map.fetch!(node, "value"),
        ttl: Map.get(node, "ttl", 300)
      }
    }
  end

  defp parse_node("Action", node = %{minimum_delay: _}, brains) do
    parse_action("delay-event", node, brains)
  end

  defp parse_node("Action", node, brains) do
    with nil <- parse_action(node["type"], node, brains) do
      data = Map.get(node, "data", %{})
      type = Map.fetch!(node, "type")

      %Mu.Brain.Action{
        type: to_module(type),
        delay: Map.get(node, "delay", 0),
        data: keys_to_atoms(data)
      }
    end
  end

  defp keys_to_atoms(map = %{}) do
    Enum.into(map, %{}, fn {key, val} ->
      {String.to_atom(key), val}
    end)
  end

  # canned conditions

  defp parse_condition("room-enter", data) do
    %Kalevala.Brain.Condition{
      type: Kalevala.Brain.Conditions.EventMatch,
      data: %{
        self_trigger: data["self_trigger"] == "true",
        topic: Kalevala.Event.Movement.Notice,
        data: %{
          direction: :to
        }
      }
    }
  end

  defp parse_condition(_, _), do: nil

  # canned actions

  defp parse_action("delay-event", node, _brians) do
    data = Map.get(node, "data", %{})

    %Kalevala.Brain.Action{
      type: Mu.Character.DelayEventAction,
      data: %{
        topic: Map.fetch!(node, "type"),
        minimum_delay: Map.fetch!(node, "minimum_delay"),
        random_delay: Map.fetch!(node, "random_delay"),
        data: keys_to_atoms(data)
      }
    }
  end

  defp parse_action(_, _, _), do: nil

  # conversion functions

  defp channel_to_interested(channel) do
    case channel do
      "say" -> &Mu.Character.SayEvent.interested?/1
    end
  end

  defp process_match(match) do
    [key, operator, value] = String.split(match)

    operator =
      case operator do
        "==" -> "equality"
        "!=" -> "inequality"
        _ -> raise("Invalid operator '#{operator}'!")
      end

    %{key: key, operator: operator, value: value}
  end

  defp to_module(string) do
    case string do
      "say" -> Mu.Character.SayAction
      "social" -> Mu.Character.SocialAction
      "wander" -> Mu.Character.WanderAction
      "delay-event" -> Mu.Character.DelayEventAction
      _ -> raise "Error! Module '#{string}' not recognized"
    end
  end
end
