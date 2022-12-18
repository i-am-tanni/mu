defmodule Mu.Character do
  @moduledoc """
  Character callbacks for Kalevala
  """
  alias Mu.Character.Pronouns

  def fill_pronouns(character) do
    meta = %{character.meta | pronouns: Pronouns.get(character.meta.pronouns)}
    Map.put(character, :meta, meta)
  end
end

defmodule Mu.Character.PlayerMeta do
  @moduledoc """
  Specific metadata for a character in Mu
  """

  defstruct [:reply_to, :vitals, :pronouns]

  defimpl Kalevala.Meta.Trim do
    def trim(meta) do
      Map.take(meta, [:vitals, :pronouns])
    end
  end

  defimpl Kalevala.Meta.Access do
    def get(meta, key), do: Map.get(meta, key)

    def put(meta, key, value), do: Map.put(meta, key, value)
  end
end
