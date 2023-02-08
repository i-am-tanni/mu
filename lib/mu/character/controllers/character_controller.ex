defmodule Mu.Character.CharacterController do
  use Kalevala.Character.Controller

  alias Kalevala.Character
  alias Mu.Character.CharacterView
  alias Mu.Character.MoveView
  alias Mu.Character.CommandController
  alias Mu.Communication
  alias Mu.CharacterChannel
  alias Mu.Character.ChannelEvent
  alias Mu.Character.TellEvent
  alias Mu.Character.MoveEvent

  @impl true
  def init(conn) do
    name = get_flash(conn, :username)
    process_character(conn, name)
  end

  @impl true
  def recv(conn, ""), do: conn

  defp process_character(conn, name) do
    character = build_character(name)

    conn
    |> put_character(character)
    |> move(:to, character.room_id, MoveView, "enter", %{})
    |> subscribe("rooms:#{character.room_id}", [], &MoveEvent.subscribe_error/2)
    |> register_and_subscribe_character_channel(character)
    |> subscribe("ooc", [], &ChannelEvent.subscribe_error/2)
    |> assign(:character, character)
    |> render(CharacterView, "name")
    |> event("room/look", %{})
    |> put_controller(CommandController)
  end

  defp build_character(name) do
    starting_room_id = 1

    %Character{
      id: Character.generate_id(),
      pid: self(),
      room_id: starting_room_id,
      name: name,
      status: "#{name} is here.",
      description: "#{name} is a person.",
      inventory: [
        %Kalevala.World.Item.Instance{
          id: Kalevala.World.Item.Instance.generate_id(),
          item_id: "global:potion",
          created_at: DateTime.utc_now(),
          meta: %Mu.World.Item.Meta{}
        },
        %Kalevala.World.Item.Instance{
          id: Kalevala.World.Item.Instance.generate_id(),
          item_id: "global:helm",
          created_at: DateTime.utc_now(),
          meta: %Mu.World.Item.Meta{}
        }
      ],
      meta: %Mu.Character.PlayerMeta{
        vitals: %Mu.Character.Vitals{
          health_points: 25,
          max_health_points: 25,
          skill_points: 17,
          max_skill_points: 17,
          endurance_points: 30,
          max_endurance_points: 30
        },
        pronouns: :male,
        equipment: Mu.Character.Equipment.new(:basic)
      }
    }
  end

  defp register_and_subscribe_character_channel(conn, character) do
    options = [character_id: character.id]
    :ok = Communication.register("characters:#{character.id}", CharacterChannel, options)

    options = [character: character]
    subscribe(conn, "characters:#{character.id}", options, &TellEvent.subscribe_error/2)
  end
end
