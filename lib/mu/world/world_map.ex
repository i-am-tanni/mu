defmodule Mu.World.WorldMap do
  use GenServer

  alias Mu.World.WorldMap
  alias Mu.World.WorldMap.Helpers

  defstruct [
    :graph,
    nodes: %{},
    loaded_zones: MapSet.new()
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def add_zone(zone) do
    GenServer.cast(__MODULE__, {:add_zone, zone})
  end

  def mini_map(room_id) do
    GenServer.call(__MODULE__, {:mini_map, room_id})
  end

  # private

  @impl true
  def init(_) do

    state = %WorldMap{
      graph: :digraph.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:add_zone, zone}, state) do
    state = Helpers.add_zone(state, zone)
    {:noreply, state}
  end

  @impl true
  def handle_call({:mini_map, room_id}, _from, state) do
    {:reply, Helpers.mini_map(state, room_id), state}
  end
end

defmodule Mu.World.WorldMap.MapNode do
  defstruct [:id, :symbol, :x, :y, :z]
end

defmodule Mu.World.WorldMap.Helpers do

  alias Mu.World.WorldMap
  alias Mu.World.WorldMap.MapNode
  alias Mu.World.Zone

  @xsize 5
  @ysize 5
  @xmin 0
  @ymin 0
  @xmax @xsize - 1
  @ymax @ysize - 1
  @index_max @xmax * @ysize + @ymax
  @center_x 2
  @center_y 2
  @center_index 12
  @max_depth 5
  @you_are_here "<>"

  @doc """
  Given a zone, if not already, loads rooms into the graph.
  """
  def add_zone(world_map, %Zone{id: zone_id, rooms: rooms}) do
    case not loaded?(world_map, zone_id) do
      true ->
        %{graph: graph} = world_map

        # add vertexes
        Enum.each(rooms, fn %{id: room_id} ->
          :digraph.add_vertex(graph, room_id)
        end)

        # add edges
        for %{id: from, exits: exits} <- rooms,
            %{to: to} <- exits do
          :digraph.add_edge(graph, from, to)
        end

        updated_nodes =
          Enum.reduce(rooms, world_map.nodes, fn %{id: room_id} = room, acc ->
            node =
              %MapNode{
                id: room_id,
                symbol: room.symbol,
                x: room.x,
                y: room.y,
                z: room.z
              }

            Map.put(acc, room_id, node)
          end)

        loaded_zones = MapSet.put(world_map.loaded_zones, zone_id)

        %{world_map | nodes: updated_nodes, loaded_zones: loaded_zones}

      false ->
        world_map
    end
  end

  @moduledoc """
  Renders a 5x5 mini-map where each symbol is a pair of graphemes

  ## Example

  ```
  ME  CH
  ||  ||  []
  ====<>====
  ST  ||
  []  ||
  ```
  """
  def mini_map(world_map, room_id) do
    %WorldMap{nodes: nodes, graph: graph} = world_map

    case Map.get(nodes, room_id, :uncharted) do
      %MapNode{x: x, y: y, z: z} = center ->
        map_data =
          for room_id <- neighbors({graph, nodes, z}, room_id),
              node = Map.fetch!(nodes, room_id),
              x = node.x - x + @center_x,
              y = y - node.y + @center_y,
              x <= @xmax and x >= @xmin,
              y <= @ymax and y >= @ymin,
              reduce: %{@center_index => %{center | symbol: @you_are_here}} do
            acc ->
              index2d = y * @xsize + x
              Map.put(acc, index2d, node)
          end

        Enum.map(0..@index_max, fn i ->
          case Map.get(map_data, i, :substrate) do
            %MapNode{symbol: symbol} ->
              symbol

            :substrate ->
              "  "
          end
        end)
        |> Enum.chunk_every(@xsize)

      :uncharted ->
        [
          "          ",
          "          ",
          "    <>    ",
          "          ",
          "          "
        ]
    end
  end

  defp neighbors(map_data, room_id) do
    map_data
    |> _neighbors(List.wrap(room_id))
    |> List.flatten()
  end

  defp _neighbors(map_data, room_ids, visited \\ MapSet.new(), depth \\ 0)

  defp _neighbors(_, _, _, @max_depth), do: []

  defp _neighbors({graph, nodes, z} = map_data, room_ids, visited, depth) do
    visited = MapSet.new(room_ids) |> MapSet.union(visited)

    # remove duplicates as multiple nodes can share the same neighbor in the same pass
    to_visit =
      room_ids
      |> Enum.flat_map(fn room_id ->
        for room_id <- :digraph.out_neighbours(graph, room_id),
            match?(%MapNode{z: ^z}, nodes[room_id]),
            not MapSet.member?(visited, room_id) do
          room_id
        end
      end)
      |> Enum.uniq()

    [to_visit | _neighbors(map_data, to_visit, visited, depth + 1)]
  end

  defp loaded?(%WorldMap{loaded_zones: loaded_zones}, zone_id) do
    MapSet.member?(loaded_zones, zone_id)
  end
end
