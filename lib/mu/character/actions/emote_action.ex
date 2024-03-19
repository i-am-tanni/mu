defmodule Mu.Character.EmoteAction do
  @moduledoc """
  Action to emote in a channel (e.g. a room)
  """

  use Mu.Character.Action

  alias Mu.Character.EmoteView

  @impl true
  def run(conn, params) do
    conn
    |> assign(:text, params.text)
    |> render(EmoteView, "echo")
    |> publish_message(params.channel_name, params.text, [type: "emote"], &publish_error/2)
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
