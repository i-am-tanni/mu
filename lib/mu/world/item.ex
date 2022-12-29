defmodule Mu.World.Items do
  @moduledoc false

  use Kalevala.Cache
end

defmodule Mu.World.Item do
  @moduledoc """
  Local callbacks for `Kalevala.World.Item`
  """
  use Kalevala.World.Item

  defstruct [
    :id,
    :keywords,
    :name,
    :dropped_name,
    :description,
    :callback_module,
    meta: %{},
    verbs: []
  ]

  @impl true
  def matches?(item, keyword) do
    keyword = String.downcase(keyword)
    keyword_match?(item.keywords, keyword) || String.downcase(item.short) == keyword
  end

  defp keyword_match?(keywords, keyword) do
    keywords
    |> Enum.map(&String.downcase/1)
    |> Enum.any?(fn item_keyword ->
      item_keyword == keyword
    end)
  end
end

defmodule Mu.World.Item.Meta do
  @moduledoc """
  Item metadata, implements `Kalevala.Meta`
  """

  defstruct []

  defimpl Kalevala.Meta.Trim do
    def trim(_meta), do: %{}
  end

  defimpl Kalevala.Meta.Access do
    def get(meta, key), do: Map.get(meta, key)

    def put(meta, key, value), do: Map.put(meta, key, value)
  end
end
