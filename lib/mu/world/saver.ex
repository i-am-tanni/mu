defmodule Mu.World.Saver.ZoneFile do
  @derive Jason.Encoder
  defstruct [:zone, rooms: [], items: [], characters: []]
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
            %{node: "WeightedNode", weight: weight, data: prepare_node(node)}
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
    social = with %Mu.Character.Social{command: command} <- social, do: command

    %{
      node: "Social",
      delay: node.delay,
      name: social,
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
    %{data: data, weight: weight} = node
    indents = indent(level)

    ~E"""
    <%=indents%>Node{
    <%=indents%>    weight: <%= weight %>,
    <%=indents%>    node: <%= encode(data.node, data) %>
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

    %ZoneFile{}
    |> prepare_zone(zone)
    |> prepare_rooms(zone)
    |> prepare_items(zone)
    |> prepare_characters(zone)
    |> Jason.encode!(pretty: true)
    |> save!(paths.world_path, "#{file_name}.json")
  end

  def save_brains(zone, opts \\ []) do
    paths = Map.merge(Keyword.get(opts, :paths, %{}), @paths)
    file_name = Keyword.get(opts, :file_name, zone.id)

    # Brains are loaded into a map where the keys are brain ids.
    # Therefore brain ids must be unique to prevent strange bugs.

    brain_ids =
      Brain.load_folder(paths.brain_path)
      |> Enum.filter(fn file ->
        String.match?(file, ~r/\.brain$/)
      end)
      |> Enum.map(&File.read!/1)
      |> Enum.map(&Mu.Brain.Parser.run/1)
      |> Enum.map(fn brain ->
        [brain_id] = Map.keys(brain)
        brain_id
      end)
      |> MapSet.new()

    {brains, _} =
      for %{brain: %{id: id} = brain} <- zone.characters,
          id != :brain_not_loaded,
          reduce: {[], brain_ids} do
        {brains, ids} ->
          case MapSet.member?(ids, id) do
            true ->
              unique_id = uniqify_id(id, ids)
              brain = %{brain | id: unique_id}
              {[brain | brains], MapSet.put(ids, unique_id)}

            false ->
              {[brain | brains], MapSet.put(brain_ids, id)}
          end
      end

    brains
    |> Enum.map(fn brain ->
      brain
      |> Brain.prepare()
      |> Brain.encode(brain.id)
    end)
    |> save!(paths.brain_path, "#{file_name}.brain")
  end

  def save_brain(brain, name, paths \\ %{}) do
    paths = Map.merge(paths, @paths)

    brain
    |> Brain.prepare()
    |> Brain.encode(name)
    |> save!(paths.brain_path, "#{name}.brain")
  end

  defp save!(file, path, file_name) do
    dest = Path.join(path, file_name)

    case File.exists?(dest) do
      true ->
        # if file exists already, create a backup
        temp_path = Path.join(path, "tmp")
        if !File.dir?(temp_path), do: File.mkdir!(temp_path)
        temp = Path.join(temp_path, file_name)
        File.copy!(dest, temp)

        with {:error, error} <- File.write(dest, file) do
          # so that if an error is encountered on write, restore from backup
          File.copy!(temp, dest)
          raise error
        end

        File.rmdir!(temp_path)

      false ->
        File.write!(dest, file)
    end
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
        {room.template_id, prepare_room(room)}
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

  defp prepare_characters(file, zone) when zone.characters == [], do: file

  defp prepare_characters(file, zone) do
    characters =
      Enum.into(zone.characters, %{}, fn character ->
        {to_string(character.id), prepare_character(character, zone)}
      end)

    %{file | characters: characters}
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

    %{
      name: room.name,
      description: room.description,
      exits: exits,
      doors: doors,
      x: room.x,
      y: room.y,
      z: room.z,
      symbol: room.symbol
    }
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
      name: item.name,
      wear_slot: item.wear_slot,
      type: item.type,
      sub_type: item.sub_type
    }
  end

  defp prepare_character(mobile, context) do
    active? =
      case Map.get(context.character_spawners, mobile.id) do
        %{active?: active?} -> active?
        nil -> false
      end

    spawn_rules = mobile.spawn_rules
    spawn_rules = %{
      active?: active?,
      minimum_count: spawn_rules.minimum_count,
      maximum_count: spawn_rules.maximum_count,
      minimum_delay: spawn_rules.minimum_delay,
      random_delay: spawn_rules.random_delay,
      strategy: spawn_rules.strategy
    }

    brain_id =
      case mobile.brain do
        %{id: id} -> id
        _ -> :brain_not_loaded
      end

    %{
      name: mobile.name,
      keywords: mobile.keywords,
      description: mobile.description,
      spawn_rules: spawn_rules,
      brain: brain_id
    }
  end

  defp uniqify_id(id, ids, count \\ 1) do
    try_id = "#{id}#{count}"
    case MapSet.member?(ids, try_id) do
      true -> uniqify_id(id, ids, count + 1)
      false -> try_id
    end
   end

end
