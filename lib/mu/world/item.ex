defmodule Mu.World.Items do
  @moduledoc false

  use Kalevala.Cache
end

defmodule Mu.World.Item.Meta do
  @moduledoc """
  Item metadata, implements `Kalevala.Meta`
  """

  defstruct [:container?, :contents]

  defimpl Kalevala.Meta.Trim do
    def trim(meta), do: Map.take(meta, [:container?, :contents])
  end

  defimpl Kalevala.Meta.Access do
    def get(meta, key), do: Map.get(meta, key)

    def put(meta, key, value), do: Map.put(meta, key, value)
  end
end

defmodule Mu.World.Item do
  @moduledoc """
  Local callbacks for `Kalevala.World.Item`
  """
  use Kalevala.World.Item
  import Mu.Utility

  alias Mu.World.Items
  alias Mu.Utility.MuEnum

  defstruct [
    :id,
    :keywords,
    :name,
    :dropped_name,
    :description,
    :callback_module,
    :wear_slot,
    :type,
    :subtype,
    meta: %{},
    verbs: []
  ]

  @impl true
  def matches?(item, keyword) do
    item.id == keyword or _matches?(item, keyword)
  end

  defp _matches?(item, keyword) do
    keyword = String.downcase(keyword)

    keyword_match? =
      item.keywords
      |> Enum.map(&String.downcase/1)
      |> Enum.any?(fn item_keyword ->
        item_keyword == keyword
      end)

    keyword_match? or String.downcase(item.name) == keyword
  end

  def fetch(item_list, item_name, ordinal) do
    result = find(item_list, item_name, ordinal)

    case maybe(result) do
      {:ok, item} -> {:ok, item}
      nil -> {:error, "unknown"}
    end
  end

  def find(item_list, item_name, ordinal) do
    MuEnum.find(item_list, ordinal, fn item_instance ->
      item = Items.get!(item_instance.item_id)
      item.callback_module.matches?(item, item_name)
    end)
  end

  def put_meta(item_instance, key, val) do
    meta = Map.put(item_instance.meta, key, val)
    %{item_instance | meta: meta}
  end

  def load(item_instance) do
    %{item_instance | item: Items.get!(item_instance.item_id)}
  end

  def instance(item_id, opts \\ []) do
    %Kalevala.World.Item.Instance{
      id: Kalevala.World.Item.Instance.generate_id(),
      item_id: item_id,
      created_at: DateTime.utc_now(),
      meta: instance_meta(opts)
    }
  end

  defp instance_meta(opts) do
    Enum.reduce(opts, %Mu.World.Item.Meta{}, fn opt, acc ->
      case opt do
        {:meta, override} -> Map.merge(acc, override)
        {:container?, true} -> Map.merge(acc, %{container?: true, contents: []})
        _ -> acc
      end
    end)
  end
end

defmodule Mu.World.Item.Container do
  alias Mu.World.Item

  def fetch(item_list, item_name, ordinal) do
    case Item.fetch(item_list, item_name, ordinal) do
      {:ok, item_instance} ->
        if container?(item_instance),
          do: {:ok, item_instance},
          else: {:error, "not-container", item_instance}

      {:error, _} ->
        {:error, {:unknown, :container}}
    end
  end

  def insert(inventory, container_instance, item_instance) do
    contents = [item_instance | container_instance.meta.contents]
    container_instance = Item.put_meta(container_instance, :contents, contents)

    item_id = item_instance.id
    container_id = container_instance.id

    inventory =
      update_item_list(inventory, fn
        %{id: ^item_id} -> :reject
        %{id: ^container_id} -> container_instance
        no_change -> no_change
      end)

    {inventory, container_instance}
  end

  def retrieve(inventory, container_instance, item_instance) do
    item_id = item_instance.id
    contents = Enum.reject(container_instance.meta.contents, &(&1.id == item_id))
    container_instance = Item.put_meta(container_instance, :contents, contents)

    container_id = container_instance.id

    inventory =
      Enum.map(inventory, fn
        %{id: ^container_id} -> container_instance
        no_change -> no_change
      end)

    inventory = [item_instance | inventory]

    {inventory, container_instance}
  end

  def validate_not_empty(container_instance) do
    contents = container_instance.meta.contents

    case contents != [] do
      true -> {:ok, contents}
      false -> {:error, "empty", container_instance}
    end
  end

  # TODO: add limits to what containers can hold
  def validate_not_full(container_instance) do
    contents = container_instance.meta.contents

    {:ok, contents}
  end

  defp container?(item_instance) do
    item_instance.meta.container?
  end

  # an approximate combination of Enum.reject() and Enum.map()
  defp update_item_list([], _), do: []

  defp update_item_list([h | t], fun) do
    case fun.(h) do
      :reject -> update_item_list(t, fun)
      item_instance -> [item_instance | update_item_list(t, fun)]
    end
  end
end

defmodule Mu.World.Item.Spawner do
  defstruct [:respawn_frequency, :respawn_at, items: []]
end
