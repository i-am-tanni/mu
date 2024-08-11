defmodule Mu.World.Saver.ZoneFile do
  @derive Jason.Encoder
  defstruct [:zone, rooms: [], items: []]
end

defmodule Mu.World.Saver.BrainPreparer do
  @moduledoc """
  Functions for encoding behavioral trees into a format to be encoded
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

  def run(%Kalevala.Brain{root: root}) do
    run([root])
  end

  def run(list) do
    Enum.map(list, fn
      %WeightedSelector{} = node ->
        nodes =
          for weight <- node.weights, node <- node.nodes do
            %{node: "WeightedNode", weight: weight, node: prepare_node(node)}
          end

        %{node: "WeightedSelector", nodes: nodes}

      %{nodes: nodes} = node ->
        type =
          case node do
            %FirstSelector{} -> "FirstSelector"
            %ConditionalSelector{} -> "ConditionalSelector"
            %Sequence{} -> "Sequence"
            %RandomSelector{} -> "RandomSelector"
          end

        %{node: type, nodes: run(nodes)}

      node ->
        prepare_node(node)
    end)
  end

  # matches

  defp prepare_node(%Condition{type: MessageMatch} = node) do
    data = node.data

    %{
      node: "MessageMatch",
      text: Regex.source(data.text),
      channel: interested_to_channel(data.interested?),
      self_trigger: data.self_trigger
    }
  end

  defp prepare_node(%Condition{type: EventMatch} = node) do
    data = node.data

    %{
      node: "EventMatch",
      topic: data.topic,
      channel: interested_to_channel(data.interested?),
      data: data.data
    }
  end

  defp prepare_node(%Condition{type: StateMatch} = node) do
    %{key: key, operator: operator, value: value} = node.data

    operator =
      case operator do
        "equality" -> "=="
        "inequality" -> "!="
        _ -> raise("Invalid operator '#{operator}'!")
      end

    %{
      node: "StateMatch",
      match: "#{key} #{operator} #{value}"
    }
  end

  defp prepare_node(%Condition{type: SocialMatch} = node) do
    data = node.data

    %{
      node: "SocialMatch",
      name: Regex.source(data.text),
      at_character: data.at_character,
      self_trigger: data.self_trigger
    }
  end

  defp prepare_node(%Action{} = node) do
    %{
      node: "Action",
      type: from_module(node.type),
      delay: node.delay,
      data: node.data
    }
  end

  defp prepare_node(%Kalevala.Brain.Action{type: DelayEventAction} = node) do
    data = node.data

    %{
      node: "DelayAction",
      type: from_module(data.topic),
      minimum_delay: data.minimum_delay,
      random_delay: data.random_delay,
      data: data.data
    }
  end

  defp prepare_node(%Social{} = node) do
    %{social: social, at_character: at_character} = node.data

    %{
      node: "SocialMatch",
      delay: node.delay,
      name: social.command,
      at_character: at_character
    }
  end

  # conversion helpers

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

defmodule Mu.World.Saver.BrainEncoder do
  @moduledoc """
  Receives prepared data from Mu.Brain.Preparer and converts it into an IO list.
  This format, once stringified, can be parsed by Mu.Brain.Parser.run()
  """

  use Kalevala.Character.View

  def run(prepared_data, brain_name) do
    ~E"""
    brain("<%= brain_name %>"){
    <%= encode(prepared_data) %>
    }
    """
  end

  defp encode(list, level \\ 1) do
    Enum.map(list, fn node ->
      encode(node.node, node, level)
    end)
  end

  defp encode(selector_type, %{nodes: nodes}, level) do
    indents = indent(level)

    ~E"""
    <%=indents%><%= selector_type %>(
    <%= encode(nodes, level + 1) %>
    <%=indents%>)
    """

  end

  defp encode("WeightedNode", node, level) do
    %{node: node, weight: weight} = node
    indents = indent(level)

    ~E"""
    <%=indents%>Node{
    <%=indents%>    weight: <%= weight %>,
    <%=indents%>    node: <%= encode(node.type, node) %>
    <%=indents%>},
    """

  end

  defp encode("MessageMatch", node, level) do
    %{text: text, channel: channel, self_trigger: self_trigger} = node
    indents = indent(level)

    ~E"""
    <%=indents%>MessageMatch{
    <%=indents%>    text: "<%= text %>",
    <%=indents%>    channel: "<%= channel %>",
    <%=indents%>    self_trigger: <%= bool_to_string!(self_trigger) %>
    <%=indents%>},
    """

  end

  defp encode("EventMatch", node, level) do
    %{topic: topic, channel: channel, data: data} = node
    indents = indent(level)

    ~E"""
    <%=indents%>EventMatch{
    <%=indents%>    topic: "<%= topic %>",
    <%=indents%>    channel: "<%= channel %>",
    <%=indents%>    data: <%= encode_map(data, level + 1) %>
    <%=indents%>},
    """

  end

  defp encode("StateMatch", node, level) do
    indents = indent(level)

    ~E"""
    <%=indents%>StateMatch{
    <%=indents%>    match: "<%= node.match %>"
    <%=indents%>},
    """

  end

  defp encode("SocialMatch", node, level) do
    %{name: name, at_character: at_character, self_trigger: self_trigger} = node
    indents = indent(level)

    ~E"""
    <%=indents%>SocialMatch{
    <%=indents%>    name: "<%= name %>",
    <%=indents%>    at_character: "<%= at_character %>",
    <%=indents%>    self_trigger: <%= bool_to_string!(self_trigger) %>
    <%=indents%>},
    """

  end

  defp encode("Action", node, level) do
    %{type: type, delay: delay, data: data} = node
    indents = indent(level)

    ~E"""
    <%=indents%>Action{
    <%=indents%>    type: "<%= type %>",
    <%=indents%>    delay: <%= Integer.to_string(delay) %>,
    <%=indents%>    data: <%= encode_map(data, level + 2) %>
    <%=indents%>},
    """

  end

  defp encode("DelayAction", node, level) do
    indents = indent(level)

    ~E"""
    <%=indents%>Action{
    <%=indents%>    type: "<%= node.type %>",
    <%=indents%>    minimum_delay: <%= node.minimum_delay %>,
    <%=indents%>    random_delay: <%= node.random_delay %>,
    <%=indents%>    data: <%= encode_map(node.data, level + 1) %>
    <%=indents%>},
    """

  end

  defp encode("Social", node, level) do
    %{name: social_name, at_character: at_character, delay: delay} = node
    indents = indent(level)

    ~E"""
    <%=indents%>Social{
    <%=indents%>    name: <%= social_name %>,
    <%=indents%>    at_character: <%= at_character %>,
    <%=indents%>    delay: <%= delay %>
    <%=indents%>},
    """

  end

  defp encode_map(map, level) do
    indents = indent(level)

    key_vals =
      Enum.map(map, fn {key, val} ->
        val =
          cond do
            is_binary(val) -> ~i("#{val}")
            is_map(val) -> encode_map(map, level + 1)
            is_integer(val) -> Integer.to_string(val)
            is_boolean(val) -> to_string(val)
            is_nil(val) -> "null"
            true -> raise("Cannot convert #{val} to string")
          end

        [indents, "#{Atom.to_string(key)}", ": ", val]
      end)

    [
    "{\n",
    Enum.map(key_vals, &[&1, "\n"]),
    indent(level - 1), "}"
    ]
  end

  defp bool_to_string!(bool) when is_boolean(bool), do: to_string(bool)
  defp bool_to_string!(val), do: raise("Expected boolean and received #{val}")

  defp indent(0), do: ""
  defp indent(n), do: Enum.map(1..n, fn _ -> "    " end)

end


defmodule Mu.World.Saver do
  @moduledoc """
  The opposite of the loader. Saves files to disk
  """

  alias Mu.World.ZoneCache
  alias Mu.World.Saver.ZoneFile
  alias Mu.Brain

  @paths %{
    world_path: "data/world",
    brain_path: "data/brains"
  }

  def save_area(zone_id, file_name, paths \\ %{}) do
    paths = Map.merge(paths, @paths)
    zone = ZoneCache.get!(zone_id)

    file =
      %ZoneFile{}
      |> prepare_zone(zone)
      |> prepare_rooms(zone)
      |> prepare_items(zone)
      |> Jason.encode!(pretty: true)

    File.write!(Path.join(paths.world_path, "#{file_name}.json"), file)
  end

  def save_brain(brain, name) do
    iolist =
      brain
      |> Brain.prepare()
      |> Brain.encode()

    File.write!(Path.join(paths.brain_path), "#{file_name}.brain", iolist)
  end

  defp prepare_zone(file, zone) do
    zone = %{
      id: zone.id,
      name: zone.name
    }

    %{file | zone: zone}
  end

  defp prepare_rooms(file, zone) when zone.rooms == [], do: file

  defp prepare_rooms(file, zone) do
    rooms =
      zone.rooms
      |> Enum.map(fn room ->
        {to_string(room.id), prepare_room(room)}
      end)
      |> Enum.into(%{})

    %{file | rooms: rooms}
  end

  defp prepare_items(file, zone) when zone.items == [], do: file

  defp prepare_items(file, zone) do
    items =
      Enum.into(zone.items, %{}, fn item ->
        {to_string(item.id), prepare_item(item)}
      end)

    %{file | items: items}
  end

  defp prepare_room(room) do
    exits =
      room.exits
      |> Enum.map(&prepare_exit/1)
      |> Enum.into(%{})

    doors =
      room.exits
      |> Enum.map(&prepare_door/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.into(%{})

    room = %{
      name: room.name,
      description: room.description,
      exits: exits
    }

    case doors != %{} do
      true -> Map.put(room, :doors, doors)
      false -> room
    end
  end

  defp prepare_exit(room_exit) do
    {room_exit.exit_name, room_exit.end_room_id}
  end

  defp prepare_door(%{door: door}) when is_nil(door), do: nil

  defp prepare_door(%{exit_name: exit_name, door: door}) do
    door = %{
      id: door.id
    }

    {exit_name, door}
  end

  defp prepare_item(item) do
    %{
      description: item.description,
      dropped_name: item.dropped_name,
      keywords: item.keywords,
      name: item.name
    }
  end
end
