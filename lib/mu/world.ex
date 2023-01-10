defmodule Mu.World do
  defstruct [:zones, :items, :rooms]
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(_opts) do
    config = Application.get_env(:mu, :world, [])
    kickoff = Keyword.get(config, :kickoff, true)

    children = [
      {Mu.World.Items, [id: Mu.World.Items, name: Mu.World.Items]},
      {Mu.World.ZoneCache, [id: Mu.World.ZoneCache, name: Mu.World.ZoneCache]},
      {Kalevala.World, [name: Mu.World]},
      {Mu.World.Kickoff, [name: Mu.World.Kickoff, start: kickoff]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def parse_id(id) do
    case Integer.parse(id) do
      {integer, ""} -> integer
      _ -> id
    end
  end
end
