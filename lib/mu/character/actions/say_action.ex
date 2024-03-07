defmodule Mu.Character.SayAction do
  @moduledoc """
  Action to speak in a channel (e.g. a room)
  """

  use Mu.Character.Action

  @impl true
  def run(conn, params) do
    publish_message(
      conn,
      params["channel_name"],
      params["text"],
      [meta: meta(params)],
      &publish_error/2
    )
  end

  @impl true
  def build(params, _opts \\ []) do
    %Action{
      type: __MODULE__,
      priority: 3,
      conditions: [:pos_sitting],
      steps: [
        Action.step(__MODULE__, 0, params)
      ]
    }
  end

  defp meta(params) do
    params
    |> Map.take(["adverb", "at_character"])
    |> Enum.into(%{}, fn {key, value} ->
      {String.to_atom(key), value}
    end)
  end

  def publish_error(conn, _error), do: conn
end
