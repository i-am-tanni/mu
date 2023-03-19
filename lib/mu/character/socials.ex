defmodule Mu.Character.Social do
  defstruct [
    :command,
    :char_no_arg,
    :others_no_arg,
    :char_found,
    :others_found,
    :vict_found,
    :char_auto,
    :others_auto
  ]
end

defmodule Mu.Character.SocialsEEx do
  import NimbleParsec

  def parser() do
    repeat(choice([text(), replacement()]))
  end

  def replacement() do
    choice([
      subject_name(),
      victim_name(),
      subject_reflexive(),
      subject_he(),
      subject_him(),
      subject_his(),
      victim_reflexive(),
      victim_him(),
      victim_his()
    ])
  end

  def subject_name() do
    ignore(string("$n"))
    |> replace(
      "<%= Mu.Character.CharacterView.render(\\\"name\\\", %{character: acting_character}) %>"
    )
  end

  def subject_he() do
    ignore(string("$e"))
    |> replace("<%= acting_character.pronouns.subject %>")
  end

  def subject_him() do
    ignore(string("$m"))
    |> replace("<%= acting_character.meta.pronouns.object %>")
  end

  def subject_reflexive() do
    ignore(string("$mself"))
    |> replace("<%= acting_character.meta.pronouns.reflexive %>")
  end

  def subject_his() do
    ignore(string("$s"))
    |> replace("<%= acting_character.meta.pronouns.possessive %>")
  end

  def victim_name() do
    ignore(string("$N"))
    |> replace(
      "<%= Mu.Character.CharacterView.render(\\\"name\\\", %{character: at_character}) %>"
    )
  end

  def victim_reflexive() do
    ignore(string("$Mself"))
    |> replace("<%= at_character.meta.pronouns.reflexive %>")
  end

  def victim_him() do
    ignore(string("$M"))
    |> replace("<%= at_character.meta.pronouns.object %>")
  end

  def victim_his() do
    ignore(string("$S"))
    |> replace("<%= at_character.meta.pronouns.possessive %>")
  end

  defp text(), do: utf8_string([not: ?$], min: 1)
end

defmodule Mu.Character.Socials do
  @moduledoc """
  Socials are emotes that account for different perspectives depending on the witness

  E.g.:
    - "command": "smile",
    - "char_no_arg": "You smile.",
    - "others_no_arg": "$n beams a warm smile.",
    - "char_found": "You smile at $N.",
    - "others_found": "$n smiles warmly at $N.",
    - "vict_found": "$n smiles warmly at you."
    - "char_auto": "You smile knowingly.",
    - "others_auto": "$n smiles knowingly to $mself.",
  """

  use Kalevala.Cache
  import NimbleParsec, only: [defparsec: 2]

  alias Mu.Character.SocialsEEx
  alias Mu.Character.Social

  defparsec(:parse, SocialsEEx.parser())

  @impl true
  def initialize(state) do
    File.read!("data/socials.json")
    |> to_eex()
    |> Jason.decode!()
    |> Enum.map(fn social ->
      %Social{
        command: social["command"],
        char_no_arg: social["char_no_arg"],
        others_no_arg: social["others_no_arg"],
        char_found: social["char_found"],
        others_found: social["others_found"],
        vict_found: social["vict_found"],
        char_auto: social["char_auto"],
        others_auto: social["others_auto"]
      }
    end)
    |> Enum.map(fn social ->
      Kalevala.Cache._put(state, social.command, social)
    end)
  end

  defp to_eex(text) do
    {:ok, result, _, _, _, _} = parse(text)
    Enum.join(result)
  end
end
