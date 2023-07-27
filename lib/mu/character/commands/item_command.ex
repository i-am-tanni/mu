defmodule Mu.Character.ItemCommand do
  use Kalevala.Character.Command

  alias Mu.World.Items
  alias Mu.Character
  alias Mu.Utility.MuEnum
  alias Mu.Character.ItemView
  alias Mu.World.Item

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

    case fetch_item(conn.character.inventory, item_name, ordinal) do
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

    with {:ok, item_instance} <- fetch_item(conn.character.inventory, item_name, ordinal),
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

  def put(conn, params) do
    container_text = params["container"]
    item_text = params["item"]
    container_ord = Map.get(params, "container/ordinal", 1)
    item_ord = Map.get(params, "item/ordinal", 1)
    inventory = conn.character.inventory

    with {:ok, container_instance} <- fetch_container(inventory, container_text, container_ord),
         {:ok, contents} <- validate_not_full(container_instance),
         {:ok, item_instance} <- fetch_item(inventory, item_text, item_ord) do
      contents = [item_instance | contents]
      container_instance = Item.put_meta(container_instance, :contents, contents)
      item_id = item_instance.id
      container_id = container_instance.id

      inventory =
        update_inventory(conn.character.inventory, fn
          %{id: ^item_id} -> :reject
          %{id: ^container_id} -> container_instance
          no_change -> no_change
        end)

      conn
      |> put_character(%{conn.character | inventory: inventory})
      |> assign(:item_instance, Item.load(item_instance))
      |> assign(:container_instance, Item.load(container_instance))
      |> prompt(ItemView, "put")
    else
      {:error, topic} ->
        render(conn, ItemView, topic)

      {:error, topic, item_instance} ->
        conn
        |> assign(:item_instance, Item.load(item_instance))
        |> render(ItemView, topic)
    end
  end

  def get_from(conn, params) do
    container_text = params["container"]
    item_text = params["item"]
    container_ord = Map.get(params, "container/ordinal", 1)
    item_ord = Map.get(params, "item/ordinal", 1)
    inventory = conn.character.inventory

    with {:ok, container_instance} <- fetch_container(inventory, container_text, container_ord),
         {:ok, contents} <- validate_not_empty(container_instance),
         {:ok, item_instance} <- fetch_item(contents, item_text, item_ord) do
      # update container contents
      item_id = item_instance.id
      contents = Enum.reject(contents, &(&1.id == item_id))
      container_instance = Item.put_meta(container_instance, :contents, contents)

      # update inventory
      container_id = container_instance.id

      inventory =
        Enum.map(conn.character.inventory, fn
          %{id: ^container_id} -> container_instance
          no_change -> no_change
        end)

      inventory = [item_instance | inventory]

      conn
      |> put_character(%{conn.character | inventory: inventory})
      |> assign(:item_instance, Item.load(item_instance))
      |> assign(:container_instance, Item.load(container_instance))
      |> prompt(ItemView, "get-from")
    else
      {:error, topic} ->
        render(conn, ItemView, topic)

      {:error, topic, item_instance} ->
        conn
        |> assign(:item_instance, Item.load(item_instance))
        |> render(ItemView, topic)
    end
  end

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

    case !is_nil(wear_slot) do
      true -> {:ok, wear_slot}
      false -> {:error, "cannot-wear"}
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

  # an approximate combination of Enum.reject() and Enum.map()
  defp update_inventory([], _), do: []

  defp update_inventory([h | t], fun) do
    case fun.(h) do
      :reject -> update_inventory(t, fun)
      item_instance -> [item_instance | update_inventory(t, fun)]
    end
  end

  defp validate_not_empty(container_instance) do
    contents = container_instance.meta.contents

    case contents != [] do
      true -> {:ok, contents}
      false -> {:error, "empty", container_instance}
    end
  end

  defp validate_not_full(container_instance) do
    contents = container_instance.meta.contents

    {:ok, contents}
  end
end
