defmodule Mu.World.Zone do
  @behaviour Kalevala.World.Zone

  defstruct [:id]

  @impl true
  def init(zone), do: zone
end
