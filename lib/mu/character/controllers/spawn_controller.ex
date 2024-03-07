defmodule Mu.Character.SpawnController do
  use Kalevala.Character.Controller

  alias Mu.Character.MoveEvent
  alias Mu.Character.NonPlayerController
  alias Mu.Character.SpawnView
  alias Mu.Character.TellEvent
  alias Mu.CharacterChannel
  alias Mu.Communication

  @impl true
  def init(conn) do
    character = conn.character
    IO.inspect("starting character #{character.name}")

    conn =
      Enum.reduce(character.meta.initial_events, conn, fn initial_event, conn ->
        delay_event(conn, initial_event.delay, initial_event.topic, initial_event.data)
      end)

    conn
    |> add_vitals()
    |> move(:to, character.room_id, SpawnView, "spawn", %{from: nil})
    |> subscribe("rooms:#{character.room_id}", [], &MoveEvent.subscribe_error/2)
    |> register_and_subscribe_character_channel(character)
    |> put_controller(NonPlayerController)
  end

  @impl true
  def recv(conn, _text), do: conn

  @impl true
  def display(conn, _text), do: conn

  def add_vitals(conn) do
    case is_nil(conn.character.meta.vitals) do
      true ->
        vitals = %Mu.Character.Vitals{
          health_points: 25,
          max_health_points: 25,
          skill_points: 0,
          max_skill_points: 0,
          endurance_points: 0,
          max_endurance_points: 0
        }

        put_meta(conn, :vitals, vitals)

      false ->
        conn
    end
  end

  defp register_and_subscribe_character_channel(conn, character) do
    options = [character_id: character.id]
    :ok = Communication.register("characters:#{character.id}", CharacterChannel, options)

    options = [character: character]
    subscribe(conn, "characters:#{character.id}", options, &TellEvent.subscribe_error/2)
  end
end
