defmodule Mu.Character.LookCommand do
  use Kalevala.Character.Command

  alias Mu.World.Items
  alias Mu.World.Item
  alias Mu.World.Item.Container
  alias Mu.Utility.MuEnum
  alias Mu.Character.LookView
  alias Mu.Character.ItemView
  alias Mu.Character.InventoryView

  def room(conn, _params) do
    conn
    |> event("room/look")
    |> assign(:prompt, false)
  end

  def run(conn, params) do
    IO.inspect(params, label: "<look>")

    case params["container"] == "" do
      true -> look(conn, params)
      false -> look_container(conn, params)
    end
  end

  defp look(conn, params) do
    text = params["text"]
    ordinal = Map.get(params, "item/ordinal", 1)

    item_instance = find_item(conn.character.inventory, text, ordinal)

    case !is_nil(item_instance) do
      true ->
        conn
        |> assign(:item_instance, Item.load(item_instance))
        |> prompt(LookView, "item")

      false ->
        send_to_room(conn, text)
    end
  end

  defp look_container(conn, params) do
    text = params["container"]
    ordinal = Map.get(params, "container/ordinal", 1)
    inventory = conn.character.inventory

    with {:ok, container_instance} <- Container.fetch(inventory, text, ordinal),
         {:ok, contents} <- Container.validate_not_empty(container_instance) do
      IO.inspect(contents, label: "<Container Contents>")

      conn
      |> assign(:container_instance, Item.load(container_instance))
      |> assign(:item_instances, Enum.map(contents, &Item.load(&1)))
      |> prompt(InventoryView, "container")
    else
      {:error, topic, item_instance} ->
        conn
        |> assign(:item_instance, Item.load(item_instance))
        |> prompt(ItemView, topic)
    end
  end

  def exits(conn, _params) do
    conn
    |> event("room/exits")
    |> assign(:prompt, false)
  end

  defp send_to_room(conn, text) do
    data = %{
      text: text,
      max_distance: 1
    }

    # max_distance: if character looks at an exit, how many rooms do they see? Default: 1

    conn
    |> event("room/look-arg", data)
    |> assign(:prompt, false)
  end

  defp find_item(item_list, item_name, ordinal) do
    MuEnum.find(item_list, ordinal, fn item_instance ->
      item = Items.get!(item_instance.item_id)
      item.callback_module.matches?(item, item_name)
    end)
  end
end
