defmodule Mu.World.WorldMap.Vertex do
  defstruct [:id, :symbol, :x, :y, :z]
end

defmodule Mu.World.WorldMap do
  @moduledoc """
  Loads vertex and edge information from area files concurrently and puts them in a directed graph.
  Remaining information for each vertex is stored in a map.

  ## Mini Map
  Mu.World.WorldMap.Helpers.mini_map/1 outputs the mini map based on the room_id.
  """
  use GenServer
  require Logger

  defstruct [:graph, vertices: %{}, loaded_zones: MapSet.new()]

  @default_path "data/world"

  alias Mu.World.WorldMap
  alias Mu.World.WorldMap.Helpers
  alias Mu.World.WorldMap.Vertex
  alias Mu.World.RoomIds

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def add_zone(zone) do
    GenServer.cast(__MODULE__, {:add_zone, zone})
  end

  def mini_map(room_id) do
    GenServer.call(__MODULE__, {:mini_map, room_id})
  end

  def reset() do
    GenServer.cast(__MODULE__, :reset)
  end

  def delete_path(from, to) do
    GenServer.cast(__MODULE__, {:delete_path, from, to})
  end

  def add_path(from, to) do
    GenServer.cast(__MODULE__, {:add_path, from, to})
  end

  def put(room) when is_struct(room, Mu.World.Room) do
    GenServer.cast(__MODULE__, {:put, room})
  end

  # private

  @impl true
  def init(opts) do
    world_path = Keyword.get(opts, :path, @default_path)
    {:ok, [], {:continue, {:load, world_path}}}
  end

  @impl true
  def handle_continue({:load, world_path}, _) do
    graph = :digraph.new()

    zones =
      for path <- load_folder(world_path),
          String.match?(path, ~r/\.json$/),
          zone = Jason.decode!(File.read!(path)),
          match?(%{"zone" => %{"id" => _}, "rooms" => _}, zone),
          %{"zone" => %{"id" => zone_id}, "rooms" => rooms} = zone do
        rooms =
          Enum.map(rooms, fn {room_id, room_data} ->
            {RoomIds.get("#{zone_id}.#{room_id}"), room_data}
          end)
        {zone_id, rooms}
      end

    vertices =
      for {_, rooms} <- zones,
          {room_id, %{"x" => x, "y" => y, "z" => z, "symbol" => symbol}} <- rooms,
          into: %{} do
        # add vertex to graph
        :digraph.add_vertex(graph, room_id)

        # finally, store data for this vertex key'd by its room id
        vertex =
          %Vertex{
            id: room_id,
            x: x,
            y: y,
            z: z,
            symbol: symbol
          }

        {room_id, vertex}
      end

    # add edges to graph. Cannot be done until all vertices are added.
    for {zone_id, rooms} <- zones,
        {room_id, %{"exits" => exits}} <- rooms,
        {_, to} <- exits do
      to =
        case is_binary(to) and String.match?(to, ~r/([^\.]+)\.([^\.]+)/) do
          true ->
            # if '.' separator is found in room exit id, assume this is in "ZoneId.room_id" format
            RoomIds.get(to)

          false ->
            # else, assume this exit refers to a local id, so combine with current zone id
            RoomIds.get("#{zone_id}.#{to}")
        end

      case :digraph.add_edge(graph, room_id, to) do
        {:error, {:bad_vertex, room_id}} ->
          Logger.warning("Missing room id referenced in exit: #{room_id}. Check all rooms referenced in exits exist.")

        _ ->
          :ok
      end
    end

    loaded_zones =
      Enum.into(zones, MapSet.new(), fn {zone_id, _} ->
        zone_id
      end)

    state = %__MODULE__{graph: graph, vertices: vertices, loaded_zones: loaded_zones}
    {:noreply, state}
  end

  @impl true
  def handle_call({:mini_map, room_id}, _from, state) do
    {:reply, Helpers.mini_map(state, room_id), state}
  end

  @impl true
  def handle_cast({:add_zone, zone}, state) do
    state = Helpers.add_zone(state, zone)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:put, %{id: id} = room}, state) do
    :digraph.add_vertex(state.graph, id)

    vertex_data =
      %Vertex{
        id: id,
        x: room.x,
        y: room.y,
        z: room.z,
        symbol: room.symbol
      }

    {:noreply, %{state | vertices: Map.put(state.vertices, id, vertex_data)}}
  end

  @impl true
  def handle_cast({:del_path, from, to}, state) do
    :digraph.del_path(state.graph, from, to)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_path, from, to}, state) do
    :digraph.add_edge(state.graph, from, to)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:reset, state) do
    # only used by tests
    :digraph.delete(state.graph)
    {:noreply, %WorldMap{graph: :digraph.new()}}
  end


  # helpers

  defp load_folder(path, acc \\ []) do
    Enum.reduce(File.ls!(path), acc, fn file, acc ->
      path = Path.join(path, file)

      case String.match?(file, ~r/\./) do
        true -> [path | acc]
        false -> load_folder(path, acc)
      end
    end)
  end

end

defmodule Mu.World.WorldMap.Helpers do

  alias Mu.World.WorldMap
  alias Mu.World.WorldMap.Vertex
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
  @max_depth 4
  @you_are_here "<>"

  @doc """
  Given a zone, if not already, loads rooms into the graph.
  """
  def add_zone(world_map, %Zone{id: zone_id, rooms: rooms}) do
    case MapSet.member?(world_map.loaded_zones, zone_id) do
      true ->
        # if already loaded, do nothing
        world_map

      false ->
        # otherwise load
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

        updated_vertices =
          Enum.reduce(rooms, world_map.vertices, fn %{id: room_id} = room, acc ->
            vertex =
              %Vertex{
                id: room_id,
                symbol: room.symbol,
                x: room.x,
                y: room.y,
                z: room.z
              }

            Map.put(acc, room_id, vertex)
          end)

        loaded_zones = MapSet.put(world_map.loaded_zones, zone_id)

        %{world_map | vertices: updated_vertices, loaded_zones: loaded_zones}
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
    %WorldMap{vertices: vertices, graph: graph} = world_map

    case Map.get(vertices, room_id, :uncharted) do
      %Vertex{x: x, y: y, z: z} = center ->
        render_data =
          for room_id <- neighbors(graph, vertices, z, room_id),
              vertex = vertices[room_id],
              x = vertex.x - x + @center_x,
              y = y - vertex.y + @center_y,
              x <= @xmax and x >= @xmin,
              y <= @ymax and y >= @ymin,
              into: %{} do
            index2d = y * @xsize + x
            {index2d, vertex}
          end
          |> Map.put(@center_index, %{center | symbol: @you_are_here})

        # index reference:
        #   00 01 02 03 04
        #   05 06 07 08 09
        #   10 11 12 13 14
        #   15 16 17 18 19
        #   20 21 22 23 24
        Enum.map(0..@index_max, fn i ->
          case Map.get(render_data, i, :substrate) do
            %Vertex{symbol: symbol} ->
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

  defp neighbors(graph, vertices, z, room_id) do
    {neighbors, _} =
      Enum.flat_map_reduce(0..@max_depth, {[room_id], MapSet.new()}, fn
        _, {[], _} = acc ->
          # nothing left to visit
          {[], acc}

        _, {room_ids, visited} ->
          visited = MapSet.new(room_ids) |> MapSet.union(visited)

          # for each room id, make a list of unique unvisited neighbors on the same z plane
          to_visit =
            for room_id <- room_ids,
                neighbor_id <- :digraph.out_neighbours(graph, room_id),
                match?(%Vertex{z: ^z}, vertices[neighbor_id]),
                not MapSet.member?(visited, neighbor_id),
                uniq: true do
              neighbor_id
            end

          {to_visit, {to_visit, visited}}
      end)

    neighbors
  end
end
