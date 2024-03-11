defmodule Mu.Character.ItemCommand do
  use Kalevala.Character.Command
  import Mu.Utility

  alias Mu.World.Items
  alias Mu.Character
  alias Mu.Utility.MuEnum
  alias Mu.Character.ItemView
  alias Mu.World.Item
  alias Mu.World.Item.Container

  # drop all
  def drop(conn, %{"text" => "all"}) do
    conn.character.inventory
    |> reject_equipment(conn)
    |> Enum.reduce(conn, &request_item_drop(&2, &1))
  end

  # drop many
  def drop(conn, params = %{"count" => count}) do
    item_name = params["item_name"]

    item_instances =
      MuEnum.find_many(conn.character.inventory, count, fn item_instance ->
        item = Items.get!(item_instance.item_id)
        item_instance.id == item_name || item.callback_module.matches?(item, item_name)
      end)
      |> reject_equipment(conn)

    case item_instances != [] do
      true ->
        item_instances
        |> Enum.reduce(conn, &request_item_drop(&2, &1))
        |> assign(:prompt, false)

      false ->
        render(conn, ItemView, "unknown", %{item_name: item_name})
    end
  end

  # drop one
  def drop(conn, params) do
    item_name = params["item_name"]
    ordinal = Map.get(params, "ordinal", 1)

    case Item.fetch(conn.character.inventory, item_name, ordinal) do
      {:ok, item_instance} ->
        case item_instance.id not in Character.get_equipment(conn, only: "item_ids") do
          true ->
            conn
            |> request_item_drop(item_instance)
            |> assign(:prompt, false)

          false ->
            conn
            |> assign(:item_instance, Item.load(item_instance))
            |> render(ItemView, "unequip-to-drop")
        end

      {:error, topic} ->
        conn
        |> assign(:item_name, item_name)
        |> render(ItemView, topic)
    end
  end

  def get(conn, params) do
    case params["container"] == "" do
      true ->
        conn
        |> request_item_pickup(params["item"])
        |> assign(:prompt, false)

      false ->
        get_from(conn, params)
    end
  end

  def wear(conn, params) do
    item_name = params["item_name"]
    ordinal = Map.get(params, "ordinal", 1)

    with {:ok, item_instance} <- Item.fetch(conn.character.inventory, item_name, ordinal),
         item <- Items.get!(item_instance.item_id),
         {:ok, wear_slot} <- fetch_wear_slot(item) do
      conn
      |> Character.put_equipment(wear_slot, item_instance)
      |> assign(:wear_slot, wear_slot)
      |> assign(:item_instance, %{item_instance | item: item})
      |> render(ItemView, "wear-item")
    else
      {:error, topic} ->
        conn
        |> assign(:item_name, item_name)
        |> render(ItemView, topic)
    end
  end

  def remove(conn, params) do
    item_name = params["item_name"]
    ordinal = Map.get(params, "ordinal", 1)

    case find_equipment(conn, item_name, ordinal) do
      {wear_slot, item_instance} ->
        item = Items.get!(item_instance.item_id)

        conn
        |> Character.put_equipment(wear_slot, %Character.Equipment.EmptySlot{})
        |> assign(:item_instance, %{item_instance | item: item})
        |> render(ItemView, "remove")

      nil ->
        conn
        |> assign(:item_name, item_name)
        |> render(ItemView, "unknown")
    end
  end

  def get_from(conn, params) do
    container_text = params["container"]
    item_text = params["item"]
    container_ord = Map.get(params, "container/ordinal", 1)
    item_ord = Map.get(params, "item/ordinal", 1)
    inventory = conn.character.inventory

    with {:ok, container_instance} <- Container.fetch(inventory, container_text, container_ord),
         {:ok, contents} <- Container.validate_not_empty(container_instance),
         {:ok, item_instance} <- Item.fetch(contents, item_text, item_ord) do
      # update container contents

      {inventory, container_instance} =
        Container.retrieve(inventory, container_instance, item_instance)

      conn
      |> put_character(%{conn.character | inventory: inventory})
      |> assign(:item_instance, Item.load(item_instance))
      |> assign(:container_instance, Item.load(container_instance))
      |> prompt(ItemView, "get-from")
    else
      {:error, {:unknown, :container}} ->
        data = %{
          container: container_text,
          item: item_text,
          container_ordinal: container_ord,
          item_ordinal: item_ord
        }

        event(conn, "room/get-from", data)

      {:error, topic} ->
        prompt(conn, ItemView, topic)

      {:error, topic, item_instance} ->
        conn
        |> assign(:item_instance, Item.load(item_instance))
        |> prompt(ItemView, topic)
    end
  end

  def put(conn, params) do
    container_text = params["container"]
    item_text = params["item"]
    container_ord = Map.get(params, "container/ordinal", 1)
    item_ord = Map.get(params, "item/ordinal", 1)
    inventory = conn.character.inventory

    item_result = Item.fetch(inventory, item_text, item_ord)

    container_result =
      with {:ok, container_instance} <- Container.fetch(inventory, container_text, container_ord),
           {:ok, _} <- Container.validate_not_full(container_instance) do
        {:ok, container_instance}
      end

    case {item_result, container_result} do
      {{:ok, item_instance}, {:ok, container_instance}} ->
        {inventory, container_instance} =
          Container.insert(inventory, container_instance, item_instance)

        conn
        |> put_character(%{conn.character | inventory: inventory})
        |> assign(:item_instance, Item.load(item_instance))
        |> assign(:container_instance, Item.load(container_instance))
        |> prompt(ItemView, "put")

      _ ->
        # If errors, try room

        data = %{
          container: container_result(container_result, container_text),
          item: item_result(item_result, item_text),
          container_ordinal: container_ord,
          item_ordinal: item_ord
        }

        event(conn, "room/put-in", data)
    end
  end

  defp container_result({:ok, container_instance}, _), do: container_instance
  defp container_result(_, container_text), do: container_text

  defp item_result({:ok, item_instance}, _), do: item_instance
  defp item_result(_, item_text), do: item_text

  defp reject_equipment(item_instances, conn) do
    equipment_item_instances = Character.get_equipment(conn, only: "items", trim: true)

    Enum.reject(item_instances, fn item_instance ->
      item_instance in equipment_item_instances
    end)
  end

  defp find_equipment(conn, item_name, ordinal) do
    Character.get_equipment(conn, trim: true)
    |> MuEnum.find(ordinal, fn {wear_slot, item_instance} ->
      item = Items.get!(item_instance.item_id)

      item.callback_module.matches?(item, item_name) or
        to_string(wear_slot) == String.downcase(item_name)
    end)
  end

  defp fetch_wear_slot(item) do
    wear_slot = item.wear_slot

    case maybe(wear_slot) do
      {:ok, wear_slot} -> {:ok, wear_slot}
      nil -> {:error, "cannot-wear"}
    end
  end
end
