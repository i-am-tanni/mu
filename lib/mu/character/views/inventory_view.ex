defmodule Mu.Character.ListView.Pluralizer do
  @moduledoc """
  Takes a count and a noun and converts it to an IO list
  I.e. 12345 and "wolf" = "twelve thousand three hundred forty five wolves"
  """

  @max_count 1_000_000_000_000

  def run(1, noun), do: ["one", ?\s, noun]

  def run(count, noun) when count <= @max_count do
    [int_to_verbose(count), ?\s, pluralize(noun)]
  end

  def run(_, _), do: raise("max count exceeded")

  defp pluralize(%{plural: override}), do: override

  defp pluralize(noun) do
    cond do
      # truss -> trusses
      Regex.match?(~r/ss$/, noun) -> [noun, "es"]
      # fish -> fishes
      Regex.match?(~r/sh$/, noun) -> [noun, "es"]
      # bunch -> bunches
      Regex.match?(~r/ch$/, noun) -> [noun, "es"]
      # crisis -> crises
      head = Regex.run(~r/\w+(?=is$)/, noun) -> [head, "es"]
      # boy -> boys
      Regex.match?(~r/\w+(?=[a,e,i,o,u]y$)/, noun) -> [noun, ?s]
      # city -> cities
      head = Regex.run(~r/\w+[^a,e,i,o,u](?=y$)/, noun) -> [head, "ies"]
      # wolf -> wolves
      head = Regex.run(~r/\w+(?=f$)/, noun) -> [head, "ves"]
      # life -> lives
      head = Regex.run(~r/\w+(?=fe$)/, noun) -> [head, "ves"]
      # focus -> foci
      head = Regex.run(~r/\w+(?=us$)/, noun) -> [head, ?i]
      # criterion -> criteria
      head = Regex.run(~r/\w+(?=on$)/, noun) -> [head, ?a]
      # ox -> oxes
      Regex.match?(~r/\w+(?=[s, x, z, o]$)/, noun) -> [noun, "es"]
      # default
      true -> [noun, "es"]
    end
  end

  defp int_to_verbose(int, count \\ 0, result \\ [])
  defp int_to_verbose(0, _, []), do: "zero"
  defp int_to_verbose(0, _, result), do: Enum.intersperse(result, ?\s)

  defp int_to_verbose(int, count, result) do
    last_two_digits = rem(int, 100)

    case rem(count, 3) == 0 and teen?(last_two_digits) do
      true ->
        result = [to_english(last_two_digits, count) | result]
        int_to_verbose(div(int, 100), count + 2, result)

      false ->
        last_digit = rem(int, 10)

        result =
          case last_digit > 0 do
            true -> [to_english(last_digit, count) | result]
            false -> result
          end

        int_to_verbose(div(int, 10), count + 1, result)
    end
  end

  defp to_english(n, power) do
    case power > 1 and rem(power, 3) != 1 do
      true -> [convert_count(n, power), ?\s, convert_power(power)]
      false -> convert_count(n, power)
    end
  end

  defp convert_power(power) do
    case power do
      x when x in [2, 5, 8, 11] -> "hundred"
      3 -> "thousand"
      6 -> "million"
      9 -> "billion"
      12 -> "trillion"
    end
  end

  defp convert_count(n, power) when rem(power, 3) != 1 do
    case n do
      1 -> "one"
      2 -> "two"
      3 -> "three"
      4 -> "four"
      5 -> "five"
      6 -> "six"
      7 -> "seven"
      8 -> "eight"
      9 -> " nine"
      _ -> convert_teen(n)
    end
  end

  defp convert_count(n, _) do
    case n do
      1 -> "ten"
      2 -> "twenty"
      3 -> "thirty"
      4 -> "forty"
      5 -> "fifty"
      6 -> "sixty"
      7 -> "seventy"
      8 -> "eighty"
      9 -> "ninety"
    end
  end

  defp convert_teen(n) do
    case n do
      11 -> "eleven"
      12 -> "twelve"
      13 -> "thirteen"
      14 -> "fourteen"
      15 -> "fifteen"
      16 -> "sixteen"
      17 -> "seventeen"
      18 -> "eighteen"
      19 -> "nineteen"
    end
  end

  defp teen?(n), do: n > 10 and n < 20
end

defmodule Mu.Character.InventoryView do
  use Kalevala.Character.View

  alias Mu.Character.ItemView

  def render("list", %{item_instances: item_instances}) do
    [
      ~i(You are holding:\n),
      render("_items", %{item_instances: item_instances})
    ]
  end

  def render("equipment-list", %{equipment: equipment, sort_order: sort_order}) do
    [
      ~i(You are wearing:\n),
      render("_equipment", %{equipment: equipment, sort_order: sort_order})
    ]
  end

  def render("equipment-list-v2", %{equipment: equipment, sort_order: sorted_keys}) do
    equipment = render("_equipment-v2", %{equipment: equipment, sort_order: sorted_keys})

    ~i(You are wearing #{equipment}.\n)
  end

  def render("_equipment", %{equipment: equipment}) when equipment == %{}, do: ~i(  Nothing!)

  def render("_equipment", %{equipment: equipment, sort_order: sorted_keys}) do
    equipment_keys = MapSet.new(Map.keys(equipment))

    sorted_keys
    |> Enum.filter(&MapSet.member?(equipment_keys, &1))
    |> Enum.map(fn wear_slot ->
      item_instance = Map.get(equipment, wear_slot)
      wear_slot = ItemView.render("wear_slot", %{wear_slot: wear_slot})
      item = render("_equipped_item", %{item_instance: item_instance})
      ~i(  #{wear_slot}: #{item})
    end)
    |> View.join("\n")
  end

  def render("_equipment-v2", %{equipment: equipment}) when equipment == %{}, do: ~i(nothing!)

  def render("_equipment-v2", %{equipment: equipment, sort_order: sorted_keys}) do
    equipment_keys = MapSet.new(Map.keys(equipment))

    sorted_keys
    |> Enum.filter(&MapSet.member?(equipment_keys, &1))
    |> Enum.map(fn wear_slot ->
      item_instance = Map.get(equipment, wear_slot)
      render("_equipped_item", %{item_instance: item_instance})
    end)
    |> listing_comma()
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

  def listing_comma(list) do
    case list do
      [list] -> list
      [one, two] -> ~i(#{one} and #{two})
      _ -> join(list, ", ", "and ")
    end
  end

  # like View.Join/2 except join/3 adds an argument for the final delim
  defp join([], _delim, _final_delim), do: []
  defp join([line], _delim, final_delim), do: [final_delim, line]
  defp join([h | t], delim, final_delim), do: [h, delim | join(t, delim, final_delim)]
end
