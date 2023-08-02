defmodule Mu.World.Room.ItemEvent do
  @moduledoc """
  Item events NOT handled by Kalevala.
  Requires modification of Kalevala to expose item_instance state to change
    in `Kalevala.World.Room.Events`.
  Note: Add and remove commands are done via `Kalevala.Character.Conn`
    request_item_drop() and request_item_pickup() functions.
  """

  import Kalevala.World.Room.Context
  alias Mu.World.Item
  alias Mu.World.Items
  alias Mu.Utility.MuEnum

  def get_from(context, event) do
    container_text = event.data.container
    item_text = event.data.item
    container_ord = event.data.container_ordinal
    item_ord = event.data.item_ordinal
    items = context.item_instances

    with {:ok, container_instance} <- fetch_container(items, container_text, container_ord),
         {:ok, contents} <- validate_not_empty(container_instance),
         {:ok, item_instance} <- fetch_item(contents, item_text, item_ord) do
      # update container contents
      item_id = item_instance.id
      contents = Enum.reject(contents, &(&1.id == item_id))
      container_instance = Item.put_meta(container_instance, :contents, contents)

      # update inventory
      container_id = container_instance.id

      items =
        Enum.map(items, fn
          %{id: ^container_id} -> container_instance
          no_change -> no_change
        end)

      context
      |> Map.put(:item_instances, items)
      |> event(event.from_pid, self(), event.topic, %{item_instance: item_instance})
    else
      {:error, topic} ->
        prompt(context, event.from_pid, ItemView, topic, %{})

      {:error, topic, item_instance} ->
        context
        |> assign(:item_instance, Item.load(item_instance))
        |> prompt(event.from_pid, ItemView, topic, %{})
    end
  end

  defp fetch_container(item_list, item_name, ordinal) do
    item_instance = find_item(item_list, item_name, ordinal)

    case item_instance do
      %{meta: meta} ->
        if meta.container?,
          do: {:ok, item_instance},
          else: {:error, "not-container", item_instance}

      nil ->
        {:error, "unknown-container"}
    end
  end

  defp fetch_item(item_list, item_name, ordinal) do
    item = find_item(item_list, item_name, ordinal)

    case !is_nil(item) do
      true -> {:ok, item}
      false -> {:error, "unknown"}
    end
  end

  defp find_item(item_list, item_name, ordinal) do
    MuEnum.find(item_list, ordinal, fn item_instance ->
      item = Items.get!(item_instance.item_id)
      item.callback_module.matches?(item, item_name)
    end)
  end

  defp validate_not_empty(container_instance) do
    contents = container_instance.meta.contents

    case contents != [] do
      true -> {:ok, contents}
      false -> {:error, "empty", container_instance}
    end
  end
end
