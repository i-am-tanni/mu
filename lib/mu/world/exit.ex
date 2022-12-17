defmodule Mu.World.Exit do
  defstruct [:id, :exit_name, :start_room_id, :end_room_id, :door, :hidden?, :secret?]
end
