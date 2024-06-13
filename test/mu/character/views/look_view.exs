defmodule Mu.Character.LookViewTest do
  use ExUnit.Case
  import Mu.Character.LookView

  alias Mu.World.Room.ExtraDesc

  test "extra desc keyword highlighting" do
    extra_desc1 = %ExtraDesc{
      keyword: "test",
      description: "This is a test."
    }

    extra_desc2 = %ExtraDesc{
      keyword: "This",
      highlight_color_override: "green",
      description: "This is a test."
    }

    assigns = %{
      description: "This is a test for testing purposes.",
      extra_descs: [extra_desc1, extra_desc2]
    }

    view = render("description", assigns)
    view = :erlang.iolist_to_binary(view)
    desired_result = ~s({color foreground="green"}This{/color} is a {color foreground="white"}test{/color} for {color foreground="white"}test{/color}ing purposes.)
    assert view == desired_result
  end

end
