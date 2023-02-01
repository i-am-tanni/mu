defmodule Mu.Character.InventoryCommand do
  use Kalevala.Character.Command

  alias Mu.Character
  alias Mu.Character.InventoryView
  alias Mu.World.Items

  def run(conn, _params) do
    equipment_item_instances = Character.get_equipment(conn.character)

    item_instances =
      Enum.map(conn.character.inventory, fn item_instance ->
        %{item_instance | item: Items.get!(item_instance.item_id)}
      end)
      |> Enum.reject(fn item_instance ->
        item_instance in equipment_item_instances
      end)

    conn
    |> assign(:item_instances, item_instances)
    |> prompt(InventoryView, "list")
  end

  def equipment(conn, params) do
    equipment_list =
      conn.character.meta.equipment
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
