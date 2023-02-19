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

  def get(equipment), do: equipment.data
  def sort_order(equipment), do: equipment.private.sort_order

  def basic() do
    ["head", "body"]
  end
end
