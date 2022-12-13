defmodule Mu.Character.SocialParser do
  import NimbleParsec

  def parser() do
    command_statement() |> optional(character_statement()) |> eos()
  end

  def command_statement() do
    word() |> unwrap_and_tag(:command)
  end

  def character_statement() do
    word() |> unwrap_and_tag(:character)
  end

  def word() do
    utf8_string([?a..?z, ?A..?Z], min: 2)
    |> ignore_white_space()
  end

  defp ignore_white_space(combinator) do
    combinator
    |> choice([ignore(times(white_space(), min: 1)), eos()])
  end

  defp white_space(combinator \\ empty()) do
    combinator
    |> ascii_char([?\s, ?\r, ?\n, ?\t, ?\d])
  end
end

defmodule Mu.Character.SocialCommand do
  use Kalevala.Character.Command, dynamic: true

  alias Mu.Character.Socials
  alias Mu.Character.SocialParser
  alias Mu.Character.SocialAction

  import NimbleParsec, only: [defparsecp: 2]

  defparsecp(:_parse_social, SocialParser.parser())

  defp parse_social(text) do
    case _parse_social(text) do
      {:ok, result, _, _, _, _} -> {:ok, result}
      {:error, _, _, _, _, _} -> :skip
    end
  end

  @impl true
  def parse(text, _opts) do
    with {:ok, parsed_term} <- parse_social(text) do
      case Socials.get(parsed_term[:command]) do
        {:ok, social} ->
          {:dynamic, :broadcast, social.command,
           %{"social" => social, "character" => parsed_term[:character]}}

        {:error, :not_found} ->
          :skip
      end
    end
  end

  def broadcast(conn, params) do
    params = Map.put(params, "channel_name", "rooms:#{conn.character.room_id}")
    IO.inspect(params)

    conn
    |> SocialAction.run(params)
    |> assign(:prompt, false)
  end
end
