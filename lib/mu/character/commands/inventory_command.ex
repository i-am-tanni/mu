defmodule Mu.Character.InventoryCommand do
  use Kalevala.Character.Command

  alias Mu.Character
  alias Mu.Character.InventoryView
  alias Mu.World.Items

  def run(conn, _params) do
    equipment_item_instances = Character.get_equipment(conn.character, only: "items")

    item_instances =
      Enum.map(conn.character.inventory, fn item_instance ->
        case item_instance not in equipment_item_instances do
          true -> %{item_instance | item: Items.get!(item_instance.item_id)}
          false -> nil
        end
      end)
      |> Enum.reject(&is_nil(&1))

    conn
    |> assign(:item_instances, item_instances)
    |> prompt(InventoryView, "list")
  end

  def equipment(conn, params) do
    equipment_list =
      Character.get_equipment(conn.character)
      |> Enum.map(fn {wear_slot, item_instance} ->
        case item_instance != %Character.Equipment.EmptySlot{} do
          true -> {wear_slot, %{item_instance | item: Items.get!(item_instance.item_id)}}
          false -> {wear_slot, %Character.Equipment.EmptySlot{}}
        end
      end)
      |> equipment_filter(params)
      |> Enum.into(%{})

    conn
    |> assign(:equipment, equipment_list)
    |> assign(:sort_order, Character.get_equipment(conn.character, only: "sort_order"))
    |> prompt(InventoryView, "equipment-list")
  end

  defp equipment_filter(equipment_list, params) do
    case params["arg"] do
      nil ->
        Enum.reject(equipment_list, fn {_, item_instance} ->
          item_instance == %Character.Equipment.EmptySlot{}
        end)

      "all" ->
        equipment_list
    end
  end
end
