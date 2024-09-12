defmodule Mu.Character.CombatMath do
  def hit?(atk, df, xl_diff) do
    mod_percent =
      xl_diff * 0.05
      |> min(0.25)
      |> max(-0.25)

    hit_chance =
      (hit_chance(atk, df) + mod_percent) * 1000
      |> min(9500)
      |> max(50)

    Enum.random(1..1000) <= hit_chance
  end

  @doc """
  Where a = the attacker's attack value and b = the defender's evasion value,
    calculates the hit chance of 1da - 1db >= 0
  """
  def hit_chance(atk, df) do
    case atk >= df do
      true ->
        atk_2x = 2 * atk
        (atk_2x - df - 1) / atk_2x

      false ->
        (atk - 1) / (2 * df)
    end
  end

  @doc """
  Converts attack rating to defense rating given a % chance to hit

  ## Examples

      iex> Mu.Character.CombatMath.atk_to_df(20, 0.75)
      9

      iex> Mu.Character.CombatMath.atk_to_df(5, 0.20)
      10

  """

  def atk_to_df(atk, hit_chance) do
    hit_chance =
      hit_chance
      |> min(0.95)
      |> max(0.05)

    result =
      case hit_chance >= 0.50 do
        true ->
          miss_chance = 1 - hit_chance
          2 * atk * miss_chance - 1

        false ->
          (atk - 1) / (2 * hit_chance)
      end

    round(result)
  end

  @doc """
  Converts defense rating to attack rating given a % chance to hit

  ## Examples

      iex> Mu.Character.CombatMath.df_to_atk(9, 0.75)
      20

      iex> Mu.Character.CombatMath.df_to_atk(10, 0.20)
      5

  """

  def df_to_atk(df, hit_chance) do
    hit_chance =
      hit_chance
      |> min(0.95)
      |> max(0.05)

    result =
      case hit_chance >= 0.50 do
        true ->
          miss_chance = 1 - hit_chance
          (df + 1) / (2 * miss_chance)

        false ->
          2 * df * hit_chance + 1
      end

    round(result)
  end

  @doc """
  Returns the attack required to achieve the marginal percent change to hit chance.

  ## Examples

      iex> Mu.Character.CombatMath.modified_atk(10, 5, 0.10)
      15

      iex> Mu.Character.CombatMath.modified_atk(5, 10, 0.05)
      6

  """

  def modified_atk(atk, df, mod_percent) do
    modded_hit_chance =
      hit_chance(atk, df) + mod_percent
      |> min(0.95)
      |> max(0.05)

    result =
      cond do
        modded_hit_chance >= 0.50 ->
          (df + 1) / (2 * (1 - modded_hit_chance))

        modded_hit_chance >= 0.05 ->
          2 * df * modded_hit_chance + 1
      end

    round(result)
  end

  @doc """
  Returns the defense required to achieve the marginal percent change to hit chance.

  ## Examples

      iex> Mu.Character.CombatMath.modified_df(10, 5, -0.10)
      7

      iex> Mu.Character.CombatMath.modified_df(10, 25, 0.12)
      15

  """

  def modified_df(atk, df, mod_percent) do
    modded_hit_chance =
      hit_chance(atk, df) + mod_percent
      |> min(0.95)
      |> max(0.05)

    result =
      cond do
        modded_hit_chance >= 0.50 ->
          atk_2x = atk * 2
          -atk_2x * modded_hit_chance + atk_2x - 1

        modded_hit_chance >= 0.05 ->
          (atk - 1) / (2 * modded_hit_chance)
      end

    round(result)
  end

end
