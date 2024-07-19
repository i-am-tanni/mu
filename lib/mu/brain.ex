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
        {:ok, data} ->
          %{type: callback_module, delay: pre_delay} = node
          action = callback_module.build(data, [])
          Mu.Character.Action.put(conn, action, pre_delay: pre_delay)

        :error ->
          conn
      end
    end
  end
end

defmodule Mu.Brain.Social do
  alias Mu.Character.SocialAction
  alias Kalevala.Brain.Variable

  defstruct [:social, :at_character, delay: 0]

  defimpl Kalevala.Brain.Node do
    def run(node, conn, _event) when is_nil(node.at_character) do
      data = Map.take(node, [:social, :at_character])
      SocialAction.put(conn, data, delay: node.delay)
    end

    def run(node, conn, event) do
      data = Map.take(node, [:at_character])

      case Variable.replace(data, event.data) do
        {:ok, data} ->
          data =
            node
            |> Map.merge(data)
            |> Map.put(:channel_name, event.data.channel_name)

          SocialAction.put(conn, data, pre_delay: node.delay)

        :error ->
          conn
      end
    end
  end
end

defmodule Mu.Brain.WeightedSelector do
  @moduledoc """
    Processes a random node based on weighted options

    Example with a 20% chance to change up the mobile's greeting:
    ```
    WeightedSelector(
      Node{
        weight: 8,
        node: Action{
          type: "say",
          delay: 500,
          data: {
              channel_name: "${channel_name}"
              text: "Hello, ${character.name}!"
          }
        },
      },
    },
      Node{
        weight: 2,
        node: Action{
          type: "say",
          delay: 500,
          data: {
              channel_name: "${channel_name}"
              text: "Hi, ${character.name}!"
          },
        },
      }
    )
    ```

  """

  defstruct [:nodes, :weights]

  defimpl Kalevala.Brain.Node do
    alias Kalevala.Brain.Node

    def run(node, conn, event) do
      %{weights: weights, nodes: nodes} = node
      selection = Enum.random(1..Enum.sum(weights))

      weights
      |> Enum.with_index()
      |> Enum.reduce_while(0, fn {weight, index}, acc ->
        acc = acc + weight

        case selection > acc do
          true -> {:cont, acc}
          false -> {:halt, Enum.at(nodes, index)}
        end
      end)
      |> Node.run(conn, event)
    end
  end
end

defmodule Mu.Brain.Conditions.SocialMatch do
  @moduledoc """
  Condition check for the message being a social and the regex matches
  """

  @behaviour Kalevala.Brain.Condition

  @impl true
  def match?(event, conn, data) do
    data.interested?.(event) and
      self_check?(event, conn, data) and
      at_character_check?(event, conn, data) and
      String.match?(event.data.text.command, data.text)
  end

  defp self_check?(event, conn, %{self_trigger: self_trigger}) do
    case event.acting_character.id == conn.character do
      true ->
        self_trigger

      false ->
        true
    end
  end

  defp at_character_check?(event, conn, data) do
    case data.at_trigger do
      true ->
        Mu.Character.matches?(conn.character, event.data.meta.at.id)

      false ->
        true
    end
  end
end

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

defmodule Mu.Brain do
  @moduledoc """
  Load and parse brain data into behavior tree structs
  """

  @brains_path "data/brains"

  @doc """
  Load brain data from the path

  Defaults to `#{@brains_path}`
  """

  def load_all(path \\ @brains_path) do
    load_folder(path)
    |> Enum.filter(fn file ->
      String.match?(file, ~r/\.brain$/)
    end)
    |> Enum.map(&File.read!/1)
    |> Enum.map(&Mu.Brain.Parser.run/1)
    |> Enum.reduce(%{}, &Map.merge(&2, &1))
  end

  defp load_folder(path, acc \\ []) do
    Enum.reduce(File.ls!(path), acc, fn file, acc ->
      path = Path.join(path, file)

      case String.match?(file, ~r/\./) do
        true -> [path | acc]
        false -> load_folder(path, acc)
      end
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

  defp parse_node("WeightedSelector", %{nodes: nodes}, brains) do
    weights = Enum.map(nodes, &Map.fetch!(&1, "weight"))
    nodes = Enum.map(nodes, &Map.fetch!(&1, "node"))

    %Mu.Brain.WeightedSelector{
      weights: weights,
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

  defp parse_node("SocialMatch", node, _brains) do
    %{"name" => text} = node
    {:ok, regex} = Regex.compile(text, "i")

    %Kalevala.Brain.Condition{
      type: Mu.Brain.Conditions.SocialMatch,
      data: %{
        interested?: &Mu.Character.SocialEvent.interested?/1,
        text: regex,
        at_trigger: node["at_trigger"] == true,
        self_trigger: node["self_trigger"] == true
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
        delay: Map.get(node, "delay", 100),
        data: keys_to_atoms(data)
      }
    end
  end

  defp parse_node("Social", node, _brains) do
    command = Map.fetch!(node, "name")

    social =
      case Mu.Character.Socials.get(command) do
        {:ok, social} -> social
        {:error, :not_found} -> raise("Social #{command} not found!")
      end

    %Mu.Brain.Social{
      social: social,
      at_character: Map.get(node, "at_character"),
      delay: Map.get(node, "delay", 100)
    }
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
