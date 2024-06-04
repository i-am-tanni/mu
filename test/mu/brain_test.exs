defmodule Mu.BrainTest do
  use ExUnit.Case
  alias Kalevala.Character
  alias Kalevala.Character.Conn

  import Mu.Brain

  test "hello" do
    brain = """
      brain("generic_hello"){
        FirstSelector(
          ConditionalSelector(
            MessageMatch{
              text: "\\bhi\\b",
              channel: "say"
            },
            Sequence(
              Action{
                type: "say",
                delay: 500,
                data: {
                  channel_name: "${channel_name}"
                  text: "Hello, ${character.name}!"
                }
              },
              Action{
                type: "say",
                delay: 750,
                data: {
                  channel_name: "${channel_name}"
                  text: "How are you?"
                }
              }
            )
          )
        )
      }
    """

    %{"generic_hello" => brain} = Mu.Brain.Parser.run(brain)

    character = %Character{
      id: Character.generate_id(),
      brain: Mu.Brain.process(brain, %{}),
      name: "character",
      room_id: "sammatti:town_square",
      meta: %Mu.Character.PlayerMeta{
        pose: :pos_standing
      }
    }

    acting_character = %Character{
      id: Kalevala.Character.generate_id(),
      name: "acting_character",
      room_id: "sammatti:town_square"
    }

    conn = %Conn{
      character: character,
      private: %Conn.Private{
        request_id: Conn.Private.generate_request_id()
      }
    }

    hi_event = %Kalevala.Event{
      acting_character: acting_character,
      topic: Kalevala.Event.Message,
      data: %Kalevala.Event.Message{
        type: "speech",
        channel_name: "rooms:sammatti:town_square",
        character: acting_character,
        text: "hi"
      }
    }

    conn = Kalevala.Brain.run(conn.character.brain, conn, hi_event)
    character = Kalevala.Character.Conn.character(conn)

    actions =
      [character.meta.processing_action, character.meta.actions]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    assert Enum.count(actions) == 2
  end

  test "wave" do
    brain = """
    brain("react_wave"){
      FirstSelector(
        ConditionalSelector(
          SocialMatch{
            name: "wave",
            at_trigger: true,
            self_trigger: false
          },
          Sequence(
            Social{
              name: "smile",
              at_character: "${character.id}",
              delay: 500
            },
            Social{
              name: "wave",
              at_character: "${character.id}",
              delay: 500
            }
          )
        )
      )
    }
    """

    %{"react_wave" => brain} = Mu.Brain.Parser.run(brain)

    character = %Character{
      id: Character.generate_id(),
      brain: Mu.Brain.process(brain, %{}),
      name: "character",
      room_id: "sammatti:town_square",
      meta: %Mu.Character.PlayerMeta{
        pose: :pos_standing
      }
    }

    acting_character = %Character{
      id: Kalevala.Character.generate_id(),
      name: "acting_character",
      room_id: "sammatti:town_square"
    }

    wave_event = %Kalevala.Event{
      acting_character: acting_character,
      topic: Kalevala.Event.Message,
      data: %Kalevala.Event.Message{
        type: "social",
        channel_name: "rooms:sammatti:town_square",
        character: acting_character,
        text: %{
          command: "wave"
        },
        meta: %{at: %{character | brain: :trimmed}}
      }
    }

    conn = %Conn{
      character: character,
      private: %Conn.Private{
        request_id: Conn.Private.generate_request_id()
      }
    }

    conn = Kalevala.Brain.run(conn.character.brain, conn, wave_event)
    character = Kalevala.Character.Conn.character(conn)
    IO.inspect(character, label: "character")

    actions =
      [character.meta.processing_action, character.meta.actions]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    assert Enum.count(actions) == 2
  end
end
