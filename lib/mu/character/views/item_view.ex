defmodule Mu.Character.ItemView do
  use Kalevala.Character.View

  def render("name", attributes = %{item_instance: item_instance}) do
    context = Map.get(attributes, :context, :none)

    item = item_instance.item

    [
      ~i({item-instance id="#{item_instance.id}" context="#{context}" name="#{item.name}" description="#{item.description}"}),
      render("name", %{item: item}),
      ~i({/item-instance})
    ]
  end

  def render("dropped_name", %{item_instance: %{item: item}}) do
    ~i({item id="#{item.id}"}#{item.dropped_name}{/item})
  end

  def render("name", %{item: item}) do
    ~i({item id="#{item.id}"}#{item.name}{/item})
  end

  def render("drop-abort", %{reason: :missing_verb, item: item}) do
    ~i(You cannot drop #{render("name", %{item: item})})
  end

  def render("drop-commit", %{item_instance: item_instance}) do
    ~i(You dropped #{render("name", %{item_instance: item_instance, context: :room})}.\n)
  end

  def render("pickup-abort", %{reason: :missing_verb, item: item}) do
    ~i(You cannot pick up #{render("name", %{item: item})}\n)
  end

  def render("pickup-commit", %{item_instance: item_instance}) do
    ~i(You picked up #{render("name", %{item_instance: item_instance, context: :inventory})}.\n)
  end

  def render("wear-item", %{wear_slot: wear_slot, item_instance: item_instance}) do
    wear_slot = render("wear_slot", %{wear_slot: wear_slot})
    item_name = render("name", %{item_instance: item_instance})
    ~i(You equip #{item_name} on your #{wear_slot}.\n)
  end

  def render("wear_slot", %{wear_slot: wear_slot}) do
    to_string(wear_slot)
  end

  def render("remove", %{item_instance: item_instance}) do
    ~i(You remove #{render("name", %{item_instance: item_instance})}.\n)
  end

  def render("unequip-to-drop", %{item_instance: item_instance}) do
    ~i(You are wearing #{render("name", %{item_instance: item_instance})}. You must {emphasize}remove{/emphasize} to drop.\n)
  end

  def render("put", assigns) do
    item = assigns.item_instance
    container = assigns.container_instance

    ~i(You put #{render("name", %{item_instance: item})} in #{render("name", %{item_instance: container})}.)
  end

  def render("get-from", assigns) do
    item = assigns.item_instance
    container = assigns.container_instance

    ~i(You get #{render("name", item)} from #{render("name", container)}.)
  end

  def render("cannot-wear", %{item_instance: instance}) do
    item_name = render("name", %{item_instance: instance})
    ~i(#{item_name} cannot be equipped.\n)
  end

  def render("unknown", %{item_name: item_name}) do
    ~i(Cannot find item {color foreground="white"}"#{item_name}"{/color}.\n)
  end

  def render("unknown", _) do
    ~i(Cannot find that item.\n)
  end

  def render("unknown-container", %{item_name: _item_name}) do
    ~i(Cannot find that container\n)
  end

  def render({"not-container"}, %{item_instance: instance}) do
    ~i(#{render("name", %{item_instance: instance})} is not a container.\n)
  end

  def render("empty", %{item_instance: instance}) do
    ~i(#{render("name", %{item_instance: instance})} is empty.\n)
  end

  def render("cannot-wear", %{}) do
    ~i(That cannot be equipped.\n)
  end

  def render("unknown-inventory", %{item_name: item_name}) do
    [
      ~i(Cannot find item {color foreground="white"}"#{item_name}"{/color} in inventory. ),
      ~i(Item must be in inventory to be equipped.\n)
    ]
  end
end
