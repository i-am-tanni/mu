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
  alias Mu.World.Item.Container

  def get_from(context, event) do
    container = event.data.container
    item = event.data.item
    container_ord = event.data.container_ordinal
    item_ord = event.data.item_ordinal
    items = context.item_instances

    with {:ok, container_instance} <- fetch_container(items, container, container_ord),
         {:ok, contents} <- Container.validate_not_empty(container_instance),
         {:ok, item_instance} <- fetch_item(contents, item, item_ord) do
      {items, container_instance} = Container.retrieve(items, container_instance, item_instance)

      data = %{
        item_instance: item_instance,
        container_instance: container_instance
      }

      context
      |> Map.put(:item_instances, items)
      |> broadcast(event.topic, data)
    else
      {:error, topic} ->
        prompt(context, event.from_pid, ItemView, topic, %{})

      {:error, topic, item_instance} ->
        context
        |> assign(:item_instance, Item.load(item_instance))
        |> prompt(event.from_pid, ItemView, topic, %{})
    end
  end

  def put(context, event) do
    container = event.data.container
    container_ord = event.data.container_ordinal
    items = context.item_instances

    with {:ok, container_instance} <- fetch_container(items, container, container_ord),
         {:ok, _contents} <- Container.validate_not_full(container_instance),
         {:ok, item_instance} <- fetch_item(items, event.data.item, event.data.item_ordinal) do
      {items, container_instance} = Container.insert(items, container_instance, item_instance)

      data = %{
        container_instance: container_instance,
        item_instance: item_instance
      }

      context
      |> Map.put(:item_instances, items)
      |> broadcast(event.topic, data)
    else
      {:error, topic} ->
        prompt(context, event.from_pid, ItemView, topic)

      {:error, topic, item_instance} ->
        context
        |> assign(:item_instance, Item.load(item_instance))
        |> prompt(event.from_pid, ItemView, topic)
    end
  end

  defp fetch_container(_, %Kalevala.World.Item.Instance{} = container_instance, _) do
    {:ok, container_instance}
  end

  defp fetch_container(items, container_text, container_ord) do
    Container.fetch(items, container_text, container_ord)
  end

  defp fetch_item(_, %Kalevala.World.Item.Instance{} = item_instance, _) do
    {:ok, item_instance}
  end

  defp fetch_item(item_list, item_name, ordinal) do
    Item.fetch(item_list, item_name, ordinal)
  end
end
