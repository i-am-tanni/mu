defmodule Mu.Character.BuildView do
  use Kalevala.Character.View

  def render("rstat", %{room: room}) do
    ~E"""
    Template_id: <%= room.template_id %>
    Zone: <%= room.zone_id %>
    Hash: <%= ~i(#{room.id}) %>
    Name: <%= room.name %>
    Coords_xyz: (<%= ~i(#{room.x}, #{room.y}, #{room.z}) %>)
    Symbol: <%= room.symbol %>
    Exits: [<%= Enum.map(room.exits, & &1.exit_name) |> View.join(", ") %>]
    Extra descs: [<%= Enum.map(room.extra_descs, & &1.keyword) |> View.join(", ") %>]
    Description: <%= room.description %>
    """
  end

  def render("dig", %{exit_name: exit_name}) do
    ~i(You dig #{exit_name}.\r\n)
  end

  def render("rset", %{key: key}) do
    ~i(Room #{key} updated.)
  end

  def render("save/success", _) do
    ~i(Zone saved successfully!)
  end

  def render("exit-added", assigns) do
    %{exit_name: exit_name, room_template_id: room_template_id, local_id: local_id} = assigns
    ~i(Exit #{exit_name} to #{room_template_id} added in #{local_id}.)
  end

  def render("exit-destroy", %{exit_name: exit_name, end_template_id: end_template_id, bi_directional?: bi_directional?}) do
    case bi_directional? do
      true -> ~i(Bi-directional exit #{exit_name} to #{end_template_id} destroyed.)
      false -> ~i(Exit #{exit_name} to #{end_template_id} destroyed.)
    end
  end

  # errors

  def render("exit-exists", %{exit_name: exit_name}) do
    ~E"""
    There is already an exit with exit name "<%= exit_name %>".
    Please dig with an unused exit name.
    """
  end

  def render("room-id-taken", %{room_id: room_id}) do
    ~i(Error: The room id "#{room_id}" is already assigned. Please choose a different room id.\r\n)
  end

  def render("invalid-exit-name", %{exit_name: exit_name}) do
    ~i(Error: Exit keyword #{exit_name} is invalid.)
  end

  def render("room-id-missing", %{room_id: room_id}) do
    ~i(Error: No room hash found for "#{room_id}".)
  end

  def render("room-pid-missing", %{room_id: room_id}) do
    ~i(Error: Could not locate process for "#{room_id}".)
  end

  def render({:room, "invalid-field"}, %{key: key}) do
    ~i(Error: Room field #{key} is invalid.)
  end

  def render({:room, "invalid-field"}, %{key: key, val: val}) do
    ~i(Error: Input #{val} is invalid for room #{key})
  end

  def render({:room, "invalid-val"}, %{key: key, val: val}) do
    ~i(Error: Room field #{val} is invalid for #{key})
  end

  def render({:room, "missing-val"}, %{key: key}) do
    ~i(Error: Room field is invalid for #{key})
  end

  def render({:mobile, "failed-to-spawn"}, %{key: key}) do
    ~i(Error: failed to spawn mobile: #{key})
  end

  def render({:mobile, "id-already-taken"}, %{key: key}) do
    ~i(Error: id already taken: #{key})
  end

  def render({:mobile, "invalid_key"}, %{key: key}) do
    ~i(Error: invalid key: #{key})
  end

  def render({:mobile, "invalid_keywords"}, %{keywords: keywords}) do
    ~i(Error: provided keywords are invalid: #{inspect keywords})
  end






  def render("zone-process-missing", _) do
    ~i(Error: Zone process cannot be found!)
  end

  def render("invalid-type", %{type: type}) do
    ~i(Error: Invalid type for removal: #{type})
  end

  def render({:exit, "not-found"}, %{keyword: keyword}) do
    ~i(Error: no exit keyword found for #{keyword}.)
  end

end
