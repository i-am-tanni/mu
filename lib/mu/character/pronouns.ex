defmodule Mu.Character.Pronouns do

  @male %{
    subject: "he",
    object: "him",
    possessive: "his",
    reflexive: "himself"
  }

  @female %{
    subject: "she",
    object: "her",
    possessive: "her",
    reflexive: "herself"
  }

  def get(pronouns) do
    case pronouns do
      :male -> @male
      :female -> @female
    end
  end

end
