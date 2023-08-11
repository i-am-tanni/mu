defmodule Mu.Character.ItemEvent do
  use Kalevala.Character.Event
  import Mu.Utility, only: [then_if: 3]

  require Logger

  alias Mu.Character.CommandView
  alias Mu.Character.ItemView
  alias Mu.World.Items

  def drop_abort(conn, %{data: %{reason: :no_item, item_name: item_name}}) do
    conn
    |> assign(:item_name, item_name)
    |> render(ItemView, "unknown")
    |> prompt(CommandView, "prompt")
  end

  def drop_abort(conn, %{data: event}) do
    %{item_instance: item_instance, reason: reason} = event

    item = Items.get!(item_instance.item_id)

    conn
    |> assign(:item, item)
    |> assign(:reason, reason)
    |> render(ItemView, "drop-abort")
    |> prompt(CommandView, "prompt")
  end

  def drop_commit(conn, %{data: event}) do
    inventory =
      Enum.reject(conn.character.inventory, fn item_instance ->
        event.item_instance.id == item_instance.id
      end)

    item = Items.get!(event.item_instance.item_id)
    item_instance = %{event.item_instance | item: item}

    conn
    |> put_character(%{conn.character | inventory: inventory})
    |> render(ItemView, "drop-commit", %{item: item, item_instance: item_instance})
    |> prompt(CommandView, "prompt")
  end

  def pickup_abort(conn, %{data: %{reason: :no_item, item_name: item_name}}) do
    conn
    |> assign(:item_name, item_name)
    |> render(ItemView, "unknown")
    |> prompt(CommandView, "prompt")
  end

  def pickup_abort(conn, %{data: event}) do
    %{item_instance: item_instance, reason: reason} = event

    item = Items.get!(item_instance.item_id)

    conn
    |> assign(:item, item)
    |> assign(:reason, reason)
    |> render(ItemView, "pickup-abort", event)
    |> prompt(CommandView, "prompt")
  end

  def pickup_commit(conn, %{data: event}) do
    inventory = [event.item_instance | conn.character.inventory]

    item = Items.get!(event.item_instance.item_id)
    item_instance = %{event.item_instance | item: item}

    conn
    |> put_character(%{conn.character | inventory: inventory})
    |> render(ItemView, "pickup-commit", %{item: item, item_instance: item_instance})
    |> prompt(CommandView, "prompt")
  end

  def get_from(conn, event) do
    acting_character? = conn.character.id == event.acting_character.id

    %{item_instance: item_instance, container_instance: container_instance} = event.data

    conn
    |> then_if(acting_character?, fn conn ->
      inventory = [item_instance | conn.character.inventory]
      put_character(conn, :inventory, inventory)
    end)
    |> assign(:item_instance, item_instance)
    |> assign(:container_instance, container_instance)
    |> render(ItemView, get_from_topic(acting_character?))
  end

  def put_in(conn, event) do
    acting_character? = conn.character.id == event.data.acting_character.id
    %{item_instance: item_instance, container_instance: container_instance} = event.data

    conn
    |> then_if(acting_character?, fn conn ->
      item_instance_id = item_instance.id
      inventory = Enum.reject(conn.character.inventory, &(&1.id == item_instance_id))
      put_character(conn, :inventory, inventory)
    end)
    |> assign(:item_instance, item_instance)
    |> assign(:container_instance, container_instance)
    |> render(ItemView, put_topic(acting_character?))
  end

  defp get_from_topic(acting_character?) do
    case acting_character? do
      true -> "get-from/actor"
      false -> "get-in/witness"
    end
  end

  defp put_topic(acting_character?) do
    case acting_character? do
      true -> "put-in/actor"
      false -> "put-in/witness"
    end
  end

  defp put_character(conn = %{character: character}, key, val) do
    character = Map.put(character, key, val)
    %{conn | character: character}
  end
end
