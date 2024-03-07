defmodule Mu.Character.Events do
  @moduledoc false

  use Kalevala.Event.Router

  alias Kalevala.Event.Movement
  alias Kalevala.Event.Message
  alias Kalevala.Event.ItemDrop
  alias Kalevala.Event.ItemPickUp
  alias Mu.Character.SayEvent
  alias Mu.Character.WhisperEvent
  alias Mu.Character.TellEvent
  alias Mu.Character.ChannelEvent
  alias Mu.Character.EmoteEvent
  alias Mu.Character.SocialEvent
  alias Mu.Character.YellEvent

  scope(Mu.Character) do
    module(CharacterEvent) do
      event(:action_next, :action_next)
    end

    module(CombatEvent) do
      event("combat/commit", :commit)
      event("combat/request", :request)
      event("combat/abort", :abort)
      event("combat/kickoff", :kickoff)
      event("round/end", :end_round)
      event("death", :death_notice)
    end

    module(BuildEvent) do
      event("room/dig", :call)
    end

    module(CloseEvent) do
      event("room/close", :call)
      event("door/close", :notice)
    end

    module(EmoteEvent) do
      event(Message, :echo, interested?: &EmoteEvent.interested?/1)
    end

    module(ItemEvent) do
      event(ItemDrop.Abort, :drop_abort)
      event(ItemDrop.Commit, :drop_commit)

      event(ItemPickUp.Abort, :pickup_abort)
      event(ItemPickUp.Commit, :pickup_commit)
      event("room/put-in", :put_in)
      event("room/get-from", :get_from)
    end

    module(MoveEvent) do
      event(Movement.Commit, :commit)
      event(Movement.Abort, :abort)
      event(Movement.Notice, :notice)
    end

    module(PathFindEvent) do
      event("room/pathfind", :call)
    end

    module(OpenEvent) do
      event("room/open", :call)
      event("door/open", :notice)
    end

    module(RandomExitEvent) do
      event("room/wander", :call)
    end

    module(SayEvent) do
      event("say/send", :broadcast)
      event(Message, :echo, interested?: &SayEvent.interested?/1)
    end

    module(YellEvent) do
      event("yell/send", :call)
      event(Message, :echo, interested?: &YellEvent.interested?/1)
    end

    module(SocialEvent) do
      event("social/send", :broadcast)
      event(Message, :echo, interested?: &SocialEvent.interested?/1)
    end

    module(TellEvent) do
      event("tell/send", :broadcast)
      event(Message, :echo, interested?: &TellEvent.interested?/1)
    end

    module(WhisperEvent) do
      event("whisper/send", :broadcast)
      event(Message, :echo, interested?: &WhisperEvent.interested?/1)
    end

    module(ChannelEvent) do
      event(Message, :echo, interested?: &ChannelEvent.interested?/1)
    end

    module(ForwardEvent) do
      event("room/look", :call)
      event("combat/end", :call)
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

defmodule Mu.Character.NonPlayerEvents do
  @moduledoc false

  use Kalevala.Event.Router

  alias Kalevala.Event.Movement

  scope(Mu.Character) do
    module(CharacterEvent) do
      event(:action_next, :action_next)
    end

    module(MoveEvent) do
      event(Movement.Commit, :commit)
      event(Movement.Notice, :notice)
      event(Movement.Abort, :abort)
    end

    module(CombatEvent) do
      event("combat/kickoff", :kickoff)
      event("combat/request", :request)
      event("combat/commit", :commit)
      event("round/end", :end_round)
      event("death", :death_notice)
    end

    module(RandomExitEvent) do
      event("room/wander", :call)
    end
  end
end
