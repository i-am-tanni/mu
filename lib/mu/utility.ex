defmodule Mu.Utility do
  @doc """
  Maps value with function if condition is true
  """
  def then_if(val, condition, fun) do
    if condition, do: fun.(val), else: val
  end

  @doc """
  Wrap result with either :ok or :error
  If there is an error, respond with {:error, error_message}
  """
  def if_err(result, error_message) do
    if result, do: {:ok, result}, else: {:error, error_message}
  end

  def maybe(nil), do: nil
  def maybe(result), do: {:ok, result}
end

defmodule Mu.Utility.MuEnum do
  @moduledoc """
  Set of algorithms built on top of Elixir.Enum
  """

  import Mu.Utility

  @doc """
  Like Enum.find except an ordinal is provided. Only the n-th match is returned.
  Ordinals are provided with "dot" notation e.g. `get 2.sword` for "get the second sword"

  If a negative ordinal is provided, the search will be conducted bottom to top.
  e.g. `get -2.sword` in natural language is equivalent to "get the SECOND TO LAST sword"

  """
  def find(list, ordinal, fun) do
    list = to_enumerable(list)

    cond do
      ordinal > 0 -> _find(list, ordinal, fun)
      ordinal < 0 -> _find(Enum.reverse(list), abs(ordinal), fun)
      true -> nil
    end
  end

  defp _find([], _, _), do: nil
  defp _find(list, 1, fun), do: Enum.find(list, fun)

  defp _find([h | t], ordinal, fun) do
    case fun.(h) do
      true -> find(t, ordinal - 1, fun)
      false -> find(t, ordinal, fun)
    end
  end

  @doc """
  Like Enum.find except a count is provided. Returns a list of matches.
  Count is provided with 'star' notation:
  e.g. `drop 2*sword` in natural language is equivalent to "drop the first two swords"

  If a negative count is provided, the LAST matches are returned.
  e.g. `drop -2*sword` in natural language is equivalent to "drop the LAST two swords"
  """

  def find_many(list, count, fun) do
    list = to_enumerable(list)

    cond do
      count > 0 -> _find_many(list, count, [], fun)
      count < 0 -> _find_many(Enum.reverse(list), abs(count), [], fun)
      true -> []
    end
  end

  defp _find_many([], _, acc, _), do: acc

  defp _find_many(list, 1, acc, fun) do
    result = Enum.find(list, fun)

    case maybe(result) do
      {:ok, item} -> [item | acc]
      nil -> acc
    end
  end

  defp _find_many([h | t], count, acc, fun) do
    case fun.(h) do
      true -> _find_many(t, count - 1, [h | acc], fun)
      false -> _find_many(t, count, acc, fun)
    end
  end

  @doc """
  Like Enum.find_value(), except an ordinal is provided.
  Only the n-th value that is neither nil nor false returned by the function is the result.
  """
  def find_value(list, ordinal, fun) do
    list = to_enumerable(list)

    cond do
      ordinal > 0 -> _find_value(list, ordinal, fun)
      ordinal < 0 -> _find_value(Enum.reverse(list), abs(ordinal), fun)
      true -> nil
    end
  end

  defp _find_value([], _, _), do: nil
  defp _find_value(list, 1, fun), do: Enum.find_value(list, fun)

  defp _find_value([h | t], ordinal, fun) do
    result = fun.(h)

    case !!result do
      true -> find_value(t, ordinal - 1, fun)
      false -> find_value(t, ordinal, fun)
    end
  end

  defp to_enumerable(list) do
    cond do
      is_map(list) -> Map.to_list(list)
      true -> list
    end
  end
end
