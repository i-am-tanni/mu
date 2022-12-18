defmodule Mu.Character.Pronouns do
  def get(pronouns) do
    case pronouns do
      :male -> male()
      :female -> female()
    end
  end

  defp male() do
    %{
      subject: "he",
      object: "him",
      possessive: "his",
      reflexive: "himself"
    }
  end

  defp female() do
    %{
      subject: "she",
      object: "her",
      possessive: "her",
      reflexive: "herself"
    }
  end
end
