defmodule Mu.Character.BuildView do
  use Kalevala.Character.View

  def render("dig", %{exit_name: exit_name}) do
    ~i(You dig #{exit_name}.\r\n)
  end

  def render("exit-exists", %{exit_name: exit_name}) do
    ~E"""
    There is already an exit with exit name "<%= exit_name %>".
    Please dig with an unused exit name.
    """
  end

  def render("room-id-taken", %{room_id: room_id}) do
    ~i(The room id "#{room_id}" is already assigned. Please choose a different room id.\r\n)
  end

  def render("invalid-exit-name", %{exit_name: exit_name}) do
    ~i(Exit keyword #{exit_name} is invalid.\r\n)
  end

end
