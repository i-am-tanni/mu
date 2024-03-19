defmodule Mu.Character.SayAction do
  @moduledoc """
  Action to speak in a channel (e.g. a room)
  """

  defstruct [:channel_name, :text, :adverb, :at_character]

  use Mu.Character.Action

  @impl true
  def run(conn, params) do
    publish_message(
      conn,
      params.channel_name,
      params.text,
      [meta: Map.take([:adverb, :at_character])],
      &publish_error/2
    )
  end

  def meta(params) do
    params
    |> Map.take([:adverb, :at_character])
    |> Enum.reject(fn {_, val} -> is_nil(val) end)
    |> Enum.into(%{})
  end

  @impl true
  def build(params, _opts \\ []) do
    %Action{
      type: __MODULE__,
      priority: 6,
      conditions: [:pos_sitting],
      steps: [
        Action.step(__MODULE__, 0, params)
      ]
    }
  end

  def publish_error(conn, _error), do: conn
end
