defmodule Mu.Communication.BroadcastChannel do
  use Kalevala.Communication.Channel
end

defmodule Mu.Communication do
  @moduledoc false

  use Kalevala.Communication

  @impl true
  def initial_channels() do
    [{"ooc", Mu.Communication.BroadcastChannel, []}]
  end
end
