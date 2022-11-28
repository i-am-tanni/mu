defmodule Mu.World do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(_opts) do
    children = [
      {Mu.World.Items, [id: Mu.World.Items, name: Mu.World.Items]},
      {Kalevala.World, [name: Mu.World]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
