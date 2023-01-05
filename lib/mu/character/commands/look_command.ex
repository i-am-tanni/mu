defmodule Mu.Character.LookCommand do
  use Kalevala.Character.Command

  alias Mu.World.Items
  alias Mu.Character.LookView

  def room(conn, _params) do
    conn
    |> event("room/look")
    |> assign(:prompt, false)
  end

  def run(conn, params) do
    text = params["text"]

    item_instance =
      Enum.find_value(conn.character.inventory, fn item_instance ->
        item = Items.get!(item_instance.item_id)

        if item_instance.id == text || item.callback_module.matches?(item, text),
          do: %{item_instance | item: item}
      end)

    case !is_nil(item_instance) do
      true ->
        conn
        |> assign(:item_instance, item_instance)
        |> render(LookView, "item")

      false ->
        conn
        |> event("room/look-arg", %{text: text})
        |> assign(:prompt, false)
    end
  end
end
