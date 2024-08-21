defmodule Mu.Brain.BuilderHelpers do
  @doc """
  Converts a behavioral tree to a list to make it easier to print the tree and make edits.
  """

  alias Kalevala.Brain.FirstSelector
  alias Kalevala.Brain.ConditionalSelector
  alias Kalevala.Brain.Sequence
  alias Kalevala.Brain.RandomSelector
  alias Mu.Brain.WeightedSelector

  alias Kalevala.Brain.Condition
  alias Kalevala.Brain.Conditions.MessageMatch
  alias Kalevala.Brain.Conditions.EventMatch
  alias Kalevala.Brain.Conditions.StateMatch
  alias Mu.Brain.Conditions.SocialMatch

  alias Mu.Brain.Action
  alias Mu.Brain.Social
  alias Mu.Character.DelayEventAction

  @moduledoc """
  Converts a behavorial tree to a list where the level key
    corresponds to which branch in the tree the node lives.
  """
  def to_list(%Kalevala.Brain{root: root}) do
    {list, _} = _to_list([root])
    Enum.reverse(list)
  end

  defp _to_list(list, acc \\ {[], 0}) do
    Enum.reduce(list, acc, fn node, {list, level} ->
      id = Kalevala.Character.generate_id()

      case node do
        %{nodes: nodes} ->
          data = %{text: to_text(node), level: level, id: id, node: node}
          list = [data | list]
          {list, _} = _to_list(nodes, {list, level + 1})
          {list, level}

        _ ->
          data = %{text: to_text(node), level: level, id: id, node: node}
          list = [data | list]
          {list, level}
      end
    end)
  end

  @doc """
  Converts a behavioral tree **list** back to a tree.
  """

  def to_tree(list, temp \\ [], acc \\ [])

  def to_tree([root], temp, acc) do
    root = %{root.node | nodes: drop_extra_fields(temp ++ acc)}
    %Kalevala.Brain{root: root}
  end

  def to_tree([h | t], [], acc), do: to_tree(t, [h], acc)

  def to_tree([h | t], [%{level: last_level} | _] = temp, acc) do
    level = h.level

    cond do
      level < last_level ->
        node = Map.put(h, :nodes, temp)
        to_tree(t, [node], acc)

      level > last_level ->
        to_tree(t, [h], temp ++ acc)

      level == last_level ->
        to_tree(t, [h | temp], acc)
    end

  end

  defp drop_extra_fields(node_list) do
    Enum.map(node_list, fn
      %{nodes: nodes, node: node} ->
        %{node | nodes: drop_extra_fields(nodes)}

      %{node: node} ->
        node
    end)
  end

  # text conversion helpers

  defp to_text(node) do
    case node do
      %FirstSelector{} ->
        "FirstSelector"

      %ConditionalSelector{} ->
        "ConditionalSelector"

      %Sequence{} ->
        "Sequence"

      %RandomSelector{} ->
        "RandomSelector"

      %Condition{type: MessageMatch, data: data} ->
        "MessageMatch #{Regex.source(data.text)}"

      %Condition{type: EventMatch, data: data} ->
        "EventMatch #{data.topic}"

      %Condition{type: StateMatch, data: data} ->
        %{key: key, operator: operator, value: value} = data
        operator = operator_to_symbol(operator)
        "StateMatch #{key} #{operator} #{value}"

      %Condition{type: SocialMatch, data: data} ->
        "SocialMatch #{Regex.source(data.text)}"

      %Action{type: DelayEventAction, data: data} ->
        "DelayAction #{from_module(data.type)}"

      %Action{type: type} ->
        "Action #{from_module(type)}"

      %Social{data: %{social: social}} ->
        "Social #{social.command}"
    end
  end

  defp operator_to_symbol(operator) do
    case operator do
      "equality" -> "=="
      "inequality" -> "!="
      _ -> raise("Invalid operator '#{operator}'!")
    end
  end

  defp interested_to_channel(interested) do
    string = "#{inspect interested}"
    cond do
      String.match?(string, ~r/SayEvent/) -> "say"
      true -> raise("module #{string} missing")
    end

  end

  defp from_module(module) do
    case module do
      Mu.Character.SayAction -> "say"
      Mu.Character.WanderAction -> "wander"
    end
  end

end
