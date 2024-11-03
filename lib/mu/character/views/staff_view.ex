defmodule Mu.Character.StaffView do
  use Kalevala.Character.View

  def render("room-not-found", %{room_id: room_id}) do
    ~i(Cannot find "#{room_id}".)
  end
end
