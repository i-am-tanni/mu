defmodule Mu.Character.PathFindCommand do
  @moduledoc """
  Breadth-first path finding.
  The character retains the visited rooms as a MapSet and rooms returns exit lists.
  PathFindEvent then determines which exits are unvisited and propagates until success or failure.
  """
  use Kalevala.Character.Command

  alias Mu.Character.PathFindData

  def track(conn, params) do
    room_id = conn.character.room_id
    id = Kalevala.Character.generate_id()

    path_find_data = %PathFindData{
      id: id,
      visited: MapSet.new([room_id]),
      lead_count: 1,
      status: :continue,
      created_at: DateTime.utc_now()
    }

    params = %{
      id: id,
      success: false,
      text: params["text"],
      steps: [],
      room_exits: [],
      depth: 0,
      max_depth: 10,
      topic: "room/track"
    }

    conn
    |> put_flash(:path_find_data, path_find_data)
    |> event("room/pathfind", params)
    |> assign(:prompt, false)
  end
end
