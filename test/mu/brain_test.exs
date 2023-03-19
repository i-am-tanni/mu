defmodule Mu.BrainTest do
  use ExUnit.Case
  alias Kalevala.Character
  alias Kalevala.Character.Conn

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

    brain = brain |> Mu.Brain.read() |> Mu.Brain.process_all()

    character = %Character{
      id: Character.generate_id(),
      brain: brain["generic_hello"],
      name: "character",
      room_id: "sammatti:town_square"
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

    move_event = %Kalevala.Event{
      acting_character: acting_character,
      topic: Kalevala.Event.Movement.Notice,
      data: %Kalevala.Event.Movement.Notice{
        character: acting_character,
        direction: :to,
        reason: "enters"
      }
    }

    conn = Kalevala.Brain.run(conn.character.brain, conn, hi_event)
    assert Enum.count(conn.private.actions) == 2
  end
end
