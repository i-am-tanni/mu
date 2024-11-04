defmodule Mu.Character.BuildView do
  use Kalevala.Character.View

  def render("dig", %{exit_name: exit_name}) do
    ~i(You dig #{exit_name}.\r\n)
  end

  def render("set", %{key: key}) do
    ~i(Room #{key} updated.)
  end

  def render("save/success", _) do
    ~i(Zone saved successfully!)
  end

  def render("exit-added", %{exit_name: exit_name, room_template_id: room_template_id}) do
    ~i(Exit to #{room_template_id} added #{exit_name}.)
  end

  # errors

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
    ~i(Exit keyword #{exit_name} is invalid.)
  end

  def render("room-id-missing", %{room_id: room_id}) do
    ~i(The room id "#{room_id}" is missing.)
  end

  def render("room-not-found", %{room_id: room_id}) do
    ~i(Cannot find "#{room_id}".)
  end

  def render({:room, "invalid-field"}, %{key: key, val: val}) do
    ~i(Input #{val} is invalid for room #{key})
  end

  def render({:room, "invalid-field"}, %{key: key}) do
    ~i(Room field #{key} is invalid.)
  end

  def render("zone-process-missing", _) do
    ~i(Error: Zone process cannot be found!)
  end

end
