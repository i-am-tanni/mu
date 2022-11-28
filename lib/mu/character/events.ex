defmodule Mu.Character.Events do
  @moduledoc false

  use Kalevala.Event.Router

  alias Kalevala.Event.Movement

  scope(Mu.Character) do
    module(MoveEvent) do
      event(Movement.Commit, :commit)
      event(Movement.Abort, :abort)
      event(Movement.Notice, :notice)
    end
  end
end

defmodule Mu.Character.IncomingEvents do
  @moduledoc false

  use Kalevala.Event.Router

  scope(Mu.Character) do
    module(ContextEvent) do
      event("Context.Lookup", :lookup)
    end
  end
end
