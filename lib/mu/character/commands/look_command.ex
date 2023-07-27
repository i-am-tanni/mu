defmodule Mu.Character.LookCommand do
  use Kalevala.Character.Command

  alias Mu.World.Items
  alias Mu.World.Item
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

    with {:ok, container_instance} <- fetch_container(inventory, text, ordinal),
         {:ok, contents} <- validate_not_empty(container_instance) do
      conn
      |> assign(:container_instance, Item.load(container_instance))
      |> assign(:item_instances, Enum.map(contents, &Item.load(&1)))
      |> prompt(InventoryView, "container")
    else
      {:error, topic, item_instance} ->
        conn
        |> assign(:item_instance, Item.load(item_instance))
        |> render(ItemView, topic)
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

  defp fetch_container(item_list, item_name, ordinal) do
    item_instance = find_item(item_list, item_name, ordinal)

    case item_instance do
      %{meta: meta} ->
        if meta.container?,
          do: {:ok, item_instance},
          else: {:error, "not-container", item_instance}

      nil ->
        {:error, "unknown-container"}
    end
  end

  defp validate_not_empty(container_instance) do
    contents = container_instance.meta.contents

    case contents != [] do
      true -> {:ok, contents}
      false -> {:error, "empty", container_instance}
    end
  end

  defp find_item(item_list, item_name, ordinal) do
    MuEnum.find(item_list, ordinal, fn item_instance ->
      item = Items.get!(item_instance.item_id)
      item.callback_module.matches?(item, item_name)
    end)
  end
end
