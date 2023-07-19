defmodule Mu.World.Items do
  @moduledoc false

  use Kalevala.Cache
end

defmodule Mu.World.Item do
  @moduledoc """
  Local callbacks for `Kalevala.World.Item`
  """
  use Kalevala.World.Item

  alias Mu.World.Items

  defstruct [
    :id,
    :keywords,
    :name,
    :dropped_name,
    :description,
    :callback_module,
    :wear_slot,
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

  def put_meta(item_instance, key, val) do
    meta = Map.put(item_instance.meta, key, val)
    %{item_instance | meta: meta}
  end

  def load(item_instance) do
    %{item_instance | item: Items.get!(item_instance.item_id)}
  end
end

defmodule Mu.World.Item.Meta do
  @moduledoc """
  Item metadata, implements `Kalevala.Meta`
  """

  defstruct [:container?, :contents]

  defimpl Kalevala.Meta.Trim do
    def trim(_meta), do: %{}
  end

  defimpl Kalevala.Meta.Access do
    def get(meta, key), do: Map.get(meta, key)

    def put(meta, key, value), do: Map.put(meta, key, value)
  end
end
