defmodule Mu.Character.BuildCommand do
  use Kalevala.Character.Command

  def dig(conn, params) do
    params = %{
      start_exit_name: params["start_exit_name"],
      end_exit_name: params["end_exit_name"],
      room_id: params["new_room_id"]
    }

    conn
    |> event("room/dig", params)
    |> assign(:prompt, false)
  end
end
