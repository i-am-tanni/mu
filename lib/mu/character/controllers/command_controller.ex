defmodule Mu.Character.CommandController do
  use Kalevala.Character.Controller

  alias Kalevala.Output.Tags
  alias Mu.Character.CommandView
  alias Mu.Character.Commands
  alias Mu.Character.Events
  alias Mu.Character.IncomingEvents

  @impl true
  def init(conn) do
    conn
    |> render(CommandView, "prompt")
  end

  @impl true
  def recv(conn, ""), do: conn

  def recv(conn, data) do
    Logger.info("Received - #{inspect(data)}")

    data = Tags.escape(data)

    case Commands.call(conn, data) do
      {:error, :unknown} ->
        conn
        |> render(CommandView, "unknown")
        |> prompt(CommandView, "prompt")

      conn ->
        case Map.get(conn.assigns, :prompt, true) do
          true ->
            prompt(conn, CommandView, "prompt", %{})

          false ->
            conn
        end
    end
  end

  @impl true
  def recv_event(conn, event) do
    Logger.debug("Received event from client - #{inspect(event)}")

    IncomingEvents.call(conn, event)
  end

  @impl true
  def event(conn, event), do: Events.call(conn, event)
end
