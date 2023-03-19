defmodule Mu.Brain.ParserTest do
  use ExUnit.Case

  test "simple case" do
    data = """
    brain("test"){
      FirstSelector(
      )
    }

    brain("message/react") {
      FirstSelector(
        ConditionalSelector(
          MessageMatch{
            text: "\\bhi\\b"
            channel: "say"
          },
          RandomSelector(
            Action{
              type: "say"
              delay: 500
              data: {
                channel_name: "$channel_name",
                text: "Hello $character_name!"
              }
            },

          )
        )
      )
    }
    """

    result = Mu.Brain.Parser.run(data)
    assert match?(result, %{})
  end

  test "complex case" do
    data = """
    brain("generic_hello"){
      ConditionalSelector(
        MessageMatch{
          text: "\bhi\b"
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
    }

    brain("villager"){
      FirstSelector(
        Node{
          ref: "generic_hello"
        },
        ConditionalSelector(
          EventMatch{
            topic: "room-enter"
          },
          Action{
            type: "say"
            delay: 500
            data: {
              channel_name: "rooms:${room_id}",
              text: "Welcome $character_name!"
            }
          }
        )
      )
    }

    brain("wandering_villager"){
      FirstSelector(
        Node{
          ref: "generic_hello"
        },
        ConditionalSelector(
          EventMatch{
            topic: "room-enter"
          },
          Action{
            type: "say"
            delay: 500
            data: {
              channel_name: "rooms:${room_id}",
              text: "Welcome $character_name!"
            }
          }
        ),
        ConditionalSelector(
          EventMatch{
            topic: "characters/move"
            data: {
              id: "wander"
            }
          },
          Action{
            type: "wander"
          },
          Action{
            type: "delay-event",
            data: {
              minimum_delay: 18000
              random_delay: 18000
              topic: "characters/move"
              data: {
                id: "${id}"
              }
            }
          }
        )
      )
    }
    """

    expected_keys = MapSet.new(~w(generic_hello villager wandering_villager))

    keys =
      data
      |> Mu.Brain.Parser.run()
      |> Map.keys()
      |> MapSet.new()

    assert MapSet.equal?(keys, expected_keys)
  end
end
