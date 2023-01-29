defmodule Mu.Character.ItemCommand do
  use Kalevala.Character.Command

  alias Mu.Character.ItemView
  alias Mu.Character.MuEnum
  alias Mu.World.Items

  def drop(conn, params = %{"count" => count}) do
    item_name = params["item_name"]

    item_instances =
      MuEnum.find_many(conn.character.inventory, count, fn item_instance ->
        item = Items.get!(item_instance.item_id)
        item_instance.id == item_name || item.callback_module.matches?(item, item_name)
      end)

    case item_instances != [] do
      true ->
        Enum.reduce(item_instances, conn, &request_item_drop(&2, &1))
        |> assign(:prompt, false)

      false ->
        render(conn, ItemView, "unknown", %{item_name: item_name})
    end
  end

  def drop(conn, params) do
    item_name = params["item_name"]
    ordinal = Map.get(params, "ordinal", 1)

    item_instance =
      MuEnum.find(conn.character.inventory, ordinal, fn item_instance ->
        item = Items.get!(item_instance.item_id)
        item_instance.id == item_name || item.callback_module.matches?(item, item_name)
      end)

    case !is_nil(item_instance) do
      true ->
        conn
        |> request_item_drop(item_instance)
        |> assign(:prompt, false)

      false ->
        render(conn, ItemView, "unknown", %{item_name: item_name})
    end
  end

  def get(conn, %{"item_name" => item_name}) do
    conn
    |> request_item_pickup(item_name)
    |> assign(:prompt, false)
  end
end
