defmodule Mu.Character.InventoryCommand do
  use Kalevala.Character.Command

  alias Mu.Character
  alias Mu.Character.InventoryView
  alias Mu.World.Item

  def run(conn, _params) do
    equipment_item_ids = Character.get_equipment(conn, only: "item_ids")

    item_instances =
      conn.character.inventory
      |> Enum.reject(&(&1.id in equipment_item_ids))
      |> Enum.map(&Item.load/1)

    conn
    |> assign(:item_instances, item_instances)
    |> prompt(InventoryView, "list")
  end

  def equipment(conn, params) do
    trim? = params["arg"] != "all"

    equipment_list =
      Character.get_equipment(conn, trim: trim?)
      |> Enum.map(fn {wear_slot, item_instance} ->
        {wear_slot, Item.load(item_instance)}
      end)
      |> Enum.into(%{})

    conn
    |> assign(:equipment, equipment_list)
    |> assign(:sort_order, Character.get_equipment(conn, only: "sort_order"))
    |> prompt(InventoryView, "equipment-list")
  end
end
