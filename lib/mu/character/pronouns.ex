defmodule Mu.Character.Pronouns do
  def untrim(character) do
    case character do
      nil ->
        nil

      character ->
        meta = Map.put(character.meta, :pronouns, get(character.meta.pronouns))
        Map.put(character, :meta, meta)
    end
  end

  defp get(group_name) do
    case group_name do
      :male -> male()
      :female -> female()
    end
  end

  def male() do
    %{
      subject: "he",
      object: "him",
      possessive: "his",
      reflexive: "himself"
    }
  end

  def female() do
    %{
      subject: "she",
      object: "her",
      possessive: "her",
      reflexive: "herself"
    }
  end
end
