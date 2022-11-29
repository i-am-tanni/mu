defmodule Mu.Character do
  @moduledoc """
  Character callbacks for Kalevala
  """
end

defmodule Mu.Character.PlayerMeta do
  @moduledoc """
  Specific metadata for a character in Kantele
  """

  defstruct [:reply_to, :vitals]

  defimpl Kalevala.Meta.Trim do
    def trim(meta) do
      Map.take(meta, [:vitals])
    end
  end

  defimpl Kalevala.Meta.Access do
    def get(meta, key), do: Map.get(meta, key)

    def put(meta, key, value), do: Map.put(meta, key, value)
  end
end
