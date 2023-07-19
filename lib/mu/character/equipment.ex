defmodule Mu.Character.Equipment.EmptySlot do
  @moduledoc """
  An empty struct for equipment slots to include by default
  """
  defstruct []
end

defmodule Mu.Character.Equipment.Private do
  defstruct [:sort_order]
end

defmodule Mu.Character.Equipment do
  defstruct [:data, private: %__MODULE__.Private{}]

  def wear_slots(template, args \\ []) do
    keys = apply(__MODULE__, template, args)

    data =
      Enum.into(keys, %{}, fn key ->
        {key, %__MODULE__.EmptySlot{}}
      end)

    private = %__MODULE__.Private{sort_order: keys}

    %__MODULE__{data: data, private: private}
  end

  def put(equipment, wear_slot, item) do
    %{equipment | data: Map.put(equipment.data, wear_slot, item)}
  end

  def get(equipment, opts) do
    case opts[:only] do
      "items" ->
        Map.values(equipment.data)

      "sort_order" ->
        equipment.private.sort_order

      "item_ids" ->
        Map.values(equipment.data)
        |> Enum.reject(&empty_slot?/1)
        |> Enum.map(& &1.id)

      _ ->
        equipment.data
    end
  end

  def trim(data, opts) do
    case Map.get(opts, :trim, true) do
      true -> Enum.reject(data, &empty_slot?/1)
      _ -> data
    end
  end

  defp empty_slot?(slot) do
    slot == %Mu.Character.Equipment.EmptySlot{} or
      match?({_, %Mu.Character.Equipment.EmptySlot{}}, slot)
  end

  def basic() do
    ["head", "body"]
  end
end
