defmodule Mu.Character.InventoryCommand do
  use Kalevala.Character.Command

  alias Mu.Character.InventoryView
  alias Mu.World.Items

  def run(conn, _params) do
    item_instances =
      Enum.map(conn.character.inventory, fn item_instance ->
        %{item_instance | item: Items.get!(item_instance.item_id)}
      end)

    conn
    |> assign(:item_instances, item_instances)
    |> prompt(InventoryView, "list")
  end
end
