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
  alias Mu.World.Item

  @impl true
  def init(conn) do
    name = get_flash(conn, :username)
    character = build_character(name)

    conn
    |> put_character(character)
    |> move(:to, character.room_id, MoveView, "respawn", %{})
    |> subscribe("rooms:#{character.room_id}", [], &MoveEvent.subscribe_error/2)
    |> register_and_subscribe_character_channel(character)
    |> subscribe("ooc", [], &ChannelEvent.subscribe_error/2)
    |> assign(:character, character)
    |> render(CharacterView, "name")
    |> event("room/look", %{})
    |> put_controller(CommandController)
  end

  @impl true
  def recv(conn, ""), do: conn

  defp build_character(name) do
    starting_room_id = Mu.World.RoomIds.get!("DefaultZone.north_room")

    %Character{
      id: Character.generate_id(),
      pid: self(),
      room_id: starting_room_id,
      name: name,
      status: "#{name} is here.",
      description: "#{name} is a person.",
      inventory: [
        Item.instance("global:potion"),
        Item.instance("global:helm"),
        Item.instance("global:bag", container?: true)
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
        pose: :pos_standing,
        equipment: Mu.Character.Equipment.wear_slots(:basic),
        in_combat?: false
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
