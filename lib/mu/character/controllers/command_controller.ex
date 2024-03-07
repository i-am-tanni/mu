defmodule Mu.Character.CommandController.PreParser do
  @moduledoc """
  Command parsing works in two phases. This is phase one.
  Substitutes command aliases and downcases most input
  """

  import NimbleParsec
  @downcase_exceptions ~w(say tell whisper emote ooc yell)

  word = utf8_string([not: ?\s, not: ?\r, not: ?\n, not: ?\t, not: ?\d], min: 1)

  command =
    word
    |> map({String, :downcase, []})
    |> map({:substitute_alias, []})
    |> unwrap_and_tag(:command)

  text =
    utf8_string([], min: 1)
    |> unwrap_and_tag(:text)

  pre_parser =
    command
    |> optional(text)
    |> wrap()
    |> map({Enum, :into, [%{}]})
    |> map({:to_binary_and_downcase, []})

  defparsec(:parse, pre_parser)

  def run(""), do: ""

  def run(data) do
    {:ok, [result], _, _, _, _} = parse(data)
    result
  end

  defp substitute_alias(verb) do
    case verb do
      "=" -> "ooc"
      "dr" -> "drop"
      "g" -> "get"
      _ -> verb
    end
  end

  defp to_binary_and_downcase(term) do
    case term do
      %{command: command, text: text} ->
        case command not in @downcase_exceptions do
          true -> command <> String.downcase(text)
          false -> command <> text
        end

      %{command: command} ->
        command
    end
  end
end

defmodule Mu.Character.CommandController do
  use Kalevala.Character.Controller

  alias Kalevala.Output.Tags
  alias Mu.Character.CombatController
  alias Mu.Character.CommandView
  alias Mu.Character.Commands
  alias Mu.Character.Events
  alias Mu.Character.IncomingEvents
  alias Mu.Character.CommandController.PreParser
  alias Mu.Output.EscapeSequences

  @impl true
  def init(conn), do: conn

  @impl true
  def recv(conn, ""), do: conn

  def recv(conn, data) do
    Logger.info("Received - #{inspect(data)}")

    data = sanitize_input(data)

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
  def event(conn, event = %{topic: "combat/kickoff"}) do
    self_id = conn.character.id
    victim_id = event.data.victim.id
    attacker_id = event.data.attacker.id

    case self_id do
      ^victim_id ->
        data = %CombatController{target: event.data.attacker, initial_event: event}
        put_controller(conn, CombatController, data)

      ^attacker_id ->
        data = %CombatController{target: event.data.victim, initial_event: event}
        put_controller(conn, CombatController, data)

      _ ->
        Events.call(conn, event)
    end
  end

  @impl true
  def event(conn, event), do: Events.call(conn, event)

  defp sanitize_input(data) do
    data
    |> Tags.escape()
    |> EscapeSequences.remove()
    |> String.trim()
    |> PreParser.run()
  end
end
