defmodule Mu.World.Zone do
  @behaviour Kalevala.World.Zone

  defstruct [:id, :name, :characters, :rooms, :items, :spawner]

  @impl true
  def init(zone), do: zone
end
