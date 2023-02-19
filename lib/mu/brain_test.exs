defmodule Mu.BrainTest do
  alias Kalevala.Brain.Node
  alias Kalevala.Character
  alias Kalevala.Character.Conn

  brains = """
  brains "generic_hello" {
    type = "conditional"
    nodes = [
      {
        type = "conditions/message-match"
        data = {
          self_trigger = false
          text = "\\bhi\\b"
        }
      },
      {
        type = "sequence"
        nodes = [
          {
            type = "actions/say"
            delay = 500
            data = {
              channel_name = "${channel_name}"
              text = "Hello, ${character.name}!"
            }
          },
          {
            type = "actions/say"
            delay = 750
            data = {
              channel_name = "${channel_name}"
              text = "How are you?"
            }
          }
        ]
      }
    ]
  }

  brains "villager" {
    type = "first"
    nodes = [
      {
        ref = brains.generic_hello
      },
      {
        type = "conditional"
        nodes = [
          {
            type = "conditions/room-enter"
            data = {
              self_trigger = false
            }
          },
          {
            type = "actions/say"
            data = {
              channel_name = "rooms:${room_id}"
              delay = 500
              text = "Welcome, ${character.name}!"
            }
          }
        ]
      }
    ]
  }

  brains "wandering_villager" {
    type = "first"
    nodes = [
      {
        type = "conditional"
        nodes = [
          {
            type = "conditions/message-match"
            data = {
              self_trigger = false
              text = "\\bhi\\b"
            }
          },
          {
            type = "sequence"
            nodes = [
              {
                type = "actions/say"
                data = {
                  channel_name = "${channel_name}"
                  text = "Hello!"
                }
              }
            ]
          }
        ]
      },
      {
        type = "conditional"
        nodes = [
          {
            type = "conditions/event-match"
            data = {
              topic = "characters/move"
              data = {
                id = "wander"
              }
            }
          },
          {
            type = "actions/wander"
          },
          {
            type = "actions/delay-event"
            data = {
              minimum_delay = 18000
              random_delay = 18000
              topic = "characters/move"
              data = {
                id = "${id}"
              }
            }
          }
        ]
      }
    ]
  }
  """

  brains = brains |> Mu.Brain.read()
  brain = Mu.Brain.process(brains["villager"], brains)

  Mu.Brain.process(brains["wandering_villager"], brains)
  |> IO.inspect(label: "wandering villager")

  character = %Character{
    id: Character.generate_id(),
    brain: brain,
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

  case Mu.Character.SayEvent.interested?(hi_event) do
    true ->
      Kalevala.Brain.run(conn.character.brain, conn, hi_event)

    false ->
      raise("SayEvent is disinterested!")
  end
end
