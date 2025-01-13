defmodule Mu.World do
  defstruct [:zones, :items, :rooms, :characters]
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
      {Mu.World.NonPlayers, [id: Mu.World.NonPlayers, name: Mu.World.NonPlayers]},
      {Mu.World.RoomIds, [id: Mu.World.RoomIds, name: Mu.World.RoomIds]},
      {Mu.World.Mapper, [id: Mu.World.Mapper, name: Mu.World.Mapper]},
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
