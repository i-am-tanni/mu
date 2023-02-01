defmodule Mu.Character.ItemCommand do
  use Kalevala.Character.Command

  alias Mu.World.Items
  alias Mu.Character
  alias Mu.Character.MuEnum
  alias Mu.Character.ItemView

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

    item_instance = find_item(conn.character.inventory, item_name, ordinal)

    case !is_nil(item_instance) do
      true ->
        case item_instance not in conn.character.meta.equipment do
          true ->
            conn
            |> request_item_drop(item_instance)
            |> assign(:prompt, false)

          false ->
            render(conn, ItemView, "unequip-to-remove", %{item_instance: item_instance})
        end

      false ->
        render(conn, ItemView, "unknown", %{item_name: item_name})
    end
  end

  def get(conn, %{"item_name" => item_name}) do
    conn
    |> request_item_pickup(item_name)
    |> assign(:prompt, false)
  end

  def wear(conn, params) do
    item_name = params["text"]
    ordinal = Map.get(params, "ordinal", 1)

    item_instance = find_item(conn.character.inventory, item_name, ordinal)

    case !is_nil(item_instance) do
      true ->
        item = Items.get!(item_instance.item_id)

        case !is_nil(item.wear_slot) do
          true ->
            character = Character.put_equipment(character(conn), item.wear_slot, item_instance)

            conn
            |> put_character(character)
            |> assign(:wear_slot, item.wear_slot)
            |> assign(:item_instance, %{item_instance | item: item})
            |> render(ItemView, "wear-item")

          false ->
            conn
            |> assign(:item_instance, %{item_instance | item: item})
            |> render(ItemView, "cannot-wear")
        end

      false ->
        conn
        |> render(ItemView, "unknown")
    end
  end

  def remove(conn, params) do
    item_name = params["text"]
    ordinal = Map.get(params, "ordinal", 1)

    result =
      conn.character.meta.equipment
      |> MuEnum.find_value(ordinal, fn {wear_slot, item_instance} ->
        item = Items.get!(item_instance)

        if item_instance.id == item_name || item.callback_module.matches?(item, item_name) ||
             to_string(wear_slot) == item_name,
           do: {wear_slot, item_instance}
      end)

    case result do
      {wear_slot, item_instance} ->
        character =
          Character.put_equipment(character(conn), wear_slot, %Character.Equipment.EmptySlot{})

        item = Items.get!(item_instance)

        conn
        |> put_character(character)
        |> assign(:item, item)

      nil ->
        conn
        |> render(ItemView, "unknown")
    end
  end

  defp reject_equipment(item_instances, %{character: character}) do
    equipment_item_instances = Character.get_equipment(character)

    Enum.reject(item_instances, fn item_instance ->
      item_instance in equipment_item_instances
    end)
  end

  defp find_item(item_list, item_name, ordinal) do
    MuEnum.find(item_list, ordinal, fn item_instance ->
      item = Items.get!(item_instance.item_id)
      item_instance.id == item_name || item.callback_module.matches?(item, item_name)
    end)
  end
end
