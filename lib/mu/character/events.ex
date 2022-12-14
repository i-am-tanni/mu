defmodule Mu.Character.Events do
  @moduledoc false

  use Kalevala.Event.Router

  alias Kalevala.Event.Movement
  alias Kalevala.Event.Message
  alias Mu.Character.SayEvent
  alias Mu.Character.WhisperEvent
  alias Mu.Character.TellEvent
  alias Mu.Character.ChannelEvent
  alias Mu.Character.EmoteEvent
  alias Mu.Character.SocialEvent

  scope(Mu.Character) do
    module(EmoteEvent) do
      event(Message, :echo, interested?: &EmoteEvent.interested?/1)
    end

    module(MoveEvent) do
      event(Movement.Commit, :commit)
      event(Movement.Abort, :abort)
      event(Movement.Notice, :notice)
    end

    module(SayEvent) do
      event("say/send", :broadcast)
      event(Message, :echo, interested?: &SayEvent.interested?/1)
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
