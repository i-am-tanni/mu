defmodule Mu.Character.InventoryView do
  use Kalevala.Character.View

  alias Mu.Character.ItemView

  def render("list", %{item_instances: item_instances}) do
    ~E"""
    You are holding:
    <%= render("_items", %{item_instances: item_instances}) %>
    """
  end

  def render("equipment-list", %{equipment: equipment}) do
    ~E"""
    You are holding:
    <%= render("_equipment", %{equipment: equipment}) %>
    """
  end

  def render("_equipment", %{equipment: equipment}) do
    equipment =
      case equipment != %{} do
        true ->
          equipment
          |> Enum.map(fn {wear_slot, item_instance} ->
            wear_slot = ItemView.render("_wear_slot", %{wear_slot: wear_slot})
            item = render("_equipped_item", %{item_instance: item_instance})
            ~i(  #{wear_slot}: #{item})
          end)
          |> View.join("\n")

        false ->
          ~i(  Nothing)
      end

    ["You are wearing:", ?\n, equipment, ?\n]
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
end
