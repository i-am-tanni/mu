defmodule Mu.Character.InventoryView do
  use Kalevala.Character.View

  alias Mu.Character.ItemView

  def render("list", %{item_instances: item_instances}) do
    [
      ~i(You are holding:\n),
      render("_items", %{item_instances: item_instances})
    ]
  end

  def render("equipment-list", %{equipment: equipment, sort_order: sort_order}) do
    [
      ~i(You are wearing:\n),
      render("_equipment", %{equipment: equipment, sort_order: sort_order})
    ]
  end

  def render("equipment-list-v2", %{equipment: equipment, sort_order: sorted_keys}) do
    equipment = render("_equipment-v2", %{equipment: equipment, sort_order: sorted_keys})

    ~i(You are wearing #{equipment}.\n)
  end

  def render("_equipment", %{equipment: equipment}) when equipment == %{}, do: ~i(  Nothing!)

  def render("_equipment", %{equipment: equipment, sort_order: sorted_keys}) do
    equipment_keys = MapSet.new(Map.keys(equipment))

    sorted_keys
    |> Enum.filter(&MapSet.member?(equipment_keys, &1))
    |> Enum.map(fn wear_slot ->
      item_instance = Map.get(equipment, wear_slot)
      wear_slot = ItemView.render("wear_slot", %{wear_slot: wear_slot})
      item = render("_equipped_item", %{item_instance: item_instance})
      ~i(  #{wear_slot}: #{item})
    end)
    |> View.join("\n")
  end

  def render("_equipment-v2", %{equipment: equipment}) when equipment == %{}, do: ~i(nothing!)

  def render("_equipment-v2", %{equipment: equipment, sort_order: sorted_keys}) do
    equipment_keys = MapSet.new(Map.keys(equipment))

    sorted_keys
    |> Enum.filter(&MapSet.member?(equipment_keys, &1))
    |> Enum.map(fn wear_slot ->
      item_instance = Map.get(equipment, wear_slot)
      render("_equipped_item", %{item_instance: item_instance})
    end)
    |> listing_comma()
  end

  def render("_equipped_item", %{item_instance: item_instance}) do
    case item_instance != %Mu.Character.Equipment.EmptySlot{} do
      true -> ~i(#{ItemView.render("name", %{item_instance: item_instance, context: :inventory})})
      false -> ~i(Empty Slot)
    end
  end

  def render("_items", %{item_instances: []}) do
    ~i(  Nothing)
  end

  def render("_items", %{item_instances: item_instances}) do
    item_instances
    |> Enum.map(&render("_item", %{item_instance: &1}))
    |> View.join("\n")
  end

  def render("_item", %{item_instance: item_instance}) do
    ~i(  #{ItemView.render("name", %{item_instance: item_instance, context: :inventory})})
  end

  def listing_comma(list) do
    case list do
      [list] -> list
      [one, two] -> ~i(#{one} and #{two})
      _ -> join(list, ", ", "and ")
    end
  end

  # like View.Join/2 except join/3 adds an argument for the final delim
  defp join([], _delim, _final_delim), do: []
  defp join([line], _delim, final_delim), do: [final_delim, line]
  defp join([h | t], delim, final_delim), do: [h, delim | join(t, delim, final_delim)]
end
