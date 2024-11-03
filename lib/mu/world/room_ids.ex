defmodule Mu.World.RoomIds do
  @moduledoc """
  Cache for looking up integer room ids generated from string identifiers sourced from the room data.
  Ids are generated from a hash provided the room string identifier.
  """

  use GenServer

  defstruct [ids: MapSet.new(), collisions: %{}]

  @i32_max Integer.pow(2, 31) - 1
  @default_path "data/world"

  # public interface

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def init(opts) do
    :ets.new(__MODULE__, [:named_table])

    world_path = Keyword.get(opts, :world_path, @default_path)

    keys =
      for path <- load_folder(world_path),
          String.match?(path, ~r/\.json$/),
          zone_data = Jason.decode!(File.read!(path)),
          match?(%{"zone" => %{"id" => _}, "rooms" => _}, zone_data),
          %{"zone" => %{"id" => zone_id}, "rooms" => rooms} = zone_data,
          room_id <- Map.keys(rooms) do
        # key that we use to generate the room id
        "#{zone_id}.#{room_id}"
      end

    {key_vals, {collisions, used_ids}} =
      Enum.map_reduce(keys, {%{}, MapSet.new()}, fn key, {collisions, ids} ->
        case generate_id(key, collisions, ids) do
          {:ok, id} ->
            acc = {collisions, MapSet.put(ids, id)}
            {{key, id}, acc}

          {:collision, id, replacement} ->
            collision = %{collision_id: id, replacement: replacement}
            collisions = Map.put(collisions, key, collision)
            acc = {collisions, MapSet.put(ids, replacement)}
            {{key, replacement}, acc}
        end
      end)

    Enum.each(key_vals, &:ets.insert(__MODULE__, &1))

    state = %__MODULE__{
      ids: used_ids,
      collisions: collisions
    }

    {:ok, state}
  end

  def get!(key) do
    with :error <- unwrap(lookup(key)) do
      # restart RoomIdCache process if there is an issue
      #   and raise an error in the calling process
      Process.exit(GenServer.whereis(__MODULE__), :kill)
      raise("Could not find expected room id for key: #{key}")
    end
  end

  def get(key), do: lookup(key)

  def put(data), do: GenServer.call(__MODULE__, {:put, data})

  def has_key?(key) do
    case lookup(key) do
      {:ok, _} -> true
      :error -> false
    end
  end

  # private

  def handle_call({:put, key}, _from, state) when is_binary(key) do
    %{ids: ids, collisions: collisions} = state

    {id, collisions} =
      case generate_id(key, collisions, ids) do
        {:ok, id} ->
          {id, collisions}

        {:collision, id, replacement} ->
          collision = %{collision_id: id, replacement: replacement}
          collisions = Map.put(collisions, key, collision)
          {replacement, collisions}
      end

    state = %{state |
      ids: MapSet.put(ids, id),
      collisions: collisions
    }

    :ets.insert(__MODULE__, {key, id})

    {:reply, id, state}
  end

  def handle_call({:put, keys}, _from, state) when is_list(keys) do
    %{ids: ids, collisions: collisions} = state

    {new_ids, {collisions, ids}} =
      Enum.map_reduce(keys, {collisions, ids}, fn key, {collisions, ids} ->
          case generate_id(key, collisions, ids) do
            {:ok, id} ->
              acc = {collisions, MapSet.put(ids, id)}
              {id, acc}

            {:collision, id, replacement} ->
              collision = %{collision_id: id, replacement: replacement}
              collisions = Map.put(collisions, key, collision)
              acc = {collisions, MapSet.put(ids, replacement)}
              {replacement, acc}
          end
      end)

    Stream.zip(keys, new_ids)
    |> Enum.each(&:ets.insert(__MODULE__, &1))

    state = %{state | ids: ids, collisions: collisions}

    {:reply, new_ids, state}
  end

  # helpers

  def load_folder(path, acc \\ []) do
    Enum.reduce(File.ls!(path), acc, fn file, acc ->
      path = Path.join(path, file)

      case String.match?(file, ~r/\./) do
        true -> [path | acc]
        false -> load_folder(path, acc)
      end
    end)
  end

  defp lookup(key) do
    case :ets.lookup(__MODULE__, key) do
      [{_, id}] -> {:ok, id}
      _ -> :error
    end
  end

  defp unwrap({:ok, result}), do: result
  defp unwrap(error), do: error

  defp generate_id(key, collisions, _) when is_map_key(collisions, key) do
    %{replacement: override} = collisions[key]
    {:ok, override}
  end

  defp generate_id(key, _, ids) do
    with :error <- lookup(key) do
      id = string_to_i32(key)
      case MapSet.member?(ids, id) do
        true -> {:collision, id, linear_probe(id + 1, ids)}
        false -> {:ok, id}
      end
    end
  end

  defp string_to_i32(s) when is_binary(s) do
    hash = :crypto.hash(:sha256, s)
    val = :binary.decode_unsigned(hash)
    # subtract 1 and add after because the lowest possible value we want is 1
    rem(val, @i32_max - 1) + 1
  end

  defp linear_probe(id, ids) when id > @i32_max, do:
    linear_probe(1, ids)

  defp linear_probe(id, ids) do
    case MapSet.member?(ids, id) do
      true -> linear_probe(id + 1, ids)
      false -> id
    end
  end

end
