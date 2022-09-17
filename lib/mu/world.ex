defmodule Mu.World do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(opts) do
    children = [
      {Kalevala.World, [name: Mu.World]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
