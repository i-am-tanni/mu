defmodule Mu.World.Arena.Damage do
  defstruct [:type, :verb, :amount]
end

defmodule Mu.World.Arena.Team do
  defstruct members: []
end

defmodule Mu.World.Arena.TurnData do
  defstruct [:id, :pid, :ap, :speed, :turn_threshold]
end

defmodule Mu.World.Arena.Context do
  def get_arena_data(context, key) do
    Map.get(context.data.arena_data, key)
  end

  def put_arena_data(context, key, data) do
    arena_data = Map.put(context.data.arena_data, key, data)
    %{context | data: Map.put(context.data, :arena_data, arena_data)}
  end

  def merge_arena_data(context, map = %{}) do
    arena_data = Map.merge(context.data.arena_data, map)
    %{context | data: Map.put(context.data, :arena_data, arena_data)}
  end
end

defmodule Mu.World.Arena.Turn do
  @moduledoc """
  Module for advancing turns
  """

  import Kalevala.World.Room.Context
  import Mu.World.Arena.Context

  alias Mu.World.Arena.Timer

  def next(context) when context.data.arena_data.on_turn_characters == [] do
    characters = get_arena_data(context, :turn_list)
    {characters, tic_count} = tic_til_turn(characters)

    on_turn_characters =
      characters
      |> Enum.filter(fn x -> x.ap >= x.turn_threshold end)
      |> Enum.sort(&(&1.ap >= &2.ap))

    IO.inspect(Enum.map(on_turn_characters, & &1.id), label: "on_turn: ")

    timers = get_arena_data(context, :timers)
    timers = tic(timers, tic_count)

    context
    |> put_arena_data(:turn_list, characters)
    |> put_arena_data(:timers, timers)
    |> resolve_timers(timers)
    |> activate_character(on_turn_characters)
  end

  def next(context) do
    on_turn_characters = get_arena_data(context, :on_turn_characters)
    activate_character(context, on_turn_characters)
  end

  defp tic_til_turn(list, count \\ 1) do
    list = Enum.map(list, fn x -> Map.put(x, :ap, x.ap + x.speed) end)

    case !Enum.any?(list, fn x -> x.ap >= x.turn_threshold end) do
      true -> tic_til_turn(list, count + 1)
      false -> {list, count}
    end
  end

  defp tic(list, count) do
    Enum.reduce(1..count, list, fn _, list ->
      Enum.map(list, fn x -> Map.put(x, :ap, x.ap + x.speed) end)
    end)
  end

  defp activate_character(context, on_turn_characters) do
    [active_character | on_turn_characters] = on_turn_characters

    IO.inspect(active_character.id, label: "!active character:")

    merge_data = %{
      active_character: active_character,
      turn_notifications: 0,
      on_turn_characters: on_turn_characters
    }

    context
    |> merge_arena_data(merge_data)
    |> event(active_character.pid, self(), "turn/notify", %{})
  end

  defp resolve_timers(context, timers) do
    timers
    |> Enum.filter(fn x -> x.ap >= x.turn_threshold end)
    |> Enum.reduce(context, fn timer, acc ->
      Timer.call(acc, timer)
    end)
  end
end

defmodule Mu.World.Arena do
  @moduledoc """
  An instanced combat-exclusive room where actions are turn based
  """
  defstruct([
    :active_character,
    :turn_notifications,
    :status,
    :waiting_for,
    :on_turn_characters,
    :turn_list,
    :timers,
    :attackers,
    :defenders
  ])
end

defmodule Mu.World.Arena.Timer do
  defstruct [:topic, :owner_id, :callback_module, :ap, :speed, :turn_threshold, events: []]
  import Kalevala.World.Room.Context

  def call(context, timer) do
    timer = timer.callback_module.call(context, timer)

    context =
      Enum.reduce(timer.events, context, fn event, context ->
        event(context, event.acting_character.pid, self(), event.topic, event.data)
      end)

    case timer.destroy? do
      true -> remove_timer(context, timer)
      false -> update_timer(context, timer)
    end
  end

  defp remove_timer(context, timer) do
    timers =
      Enum.reject(context.data.timers, fn x ->
        x.id == timer.id
      end)

    put_data(context, :timers, timers)
  end

  defp update_timer(context, timer) do
    timers =
      Enum.reject(context.data.timers, fn x ->
        x.id == timer.id
      end)

    timer = %{timer | events: []}

    put_data(context, :timers, [timer | timers])
  end
end

defmodule Mu.World.Arena.Timer.TimerEvent do
  defstruct [:pid, :topic, :target, :data]
end

defmodule Mu.World.Arena.Timer.Helpers do
  def destroy(timer), do: %{timer | destroy?: true}

  def reset(timer) do
    timer = %{timer | ap: 0}

    case !timer.infinite? do
      true ->
        timer = %{timer | resets: timer.resets - 1}

        case timer.resets > 0 do
          true -> timer
          false -> destroy(timer)
        end

      false ->
        timer
    end
  end

  def put_events(timer, events) when is_list(events), do: %{timer | events: events}
  def put_events(timer, event), do: %{timer | events: [event]}

  def get_targets(context, timer) when is_atom(timer.target) do
    case timer.target do
      :team_a -> context.data.team_a.members
      :team_b -> context.data.team_b.members
      :all -> context.characters
    end
    |> Enum.filter(& &1.alive?)
    |> Enum.map(& &1.pid)
  end

  def get_targets(_, %{target: target}), do: get_target(target)

  def get_target(%{target: target}), do: get_target(target)

  def get_target(target), do: List.wrap(target.pid)
end

defmodule Mu.World.Arena.DamageTimer do
  import Mu.World.Arena.Timer.Helpers
  alias Mu.World.Arena.Timer.TimerEvent

  def call(context, timer) do
    keys = [:damage_min, :damage_max, :damage_type]

    events =
      Enum.map(get_targets(context, timer), fn target ->
        %TimerEvent{
          pid: target.pid,
          topic: "raw/damage",
          data: Map.take(timer.data, keys)
        }
      end)

    timer
    |> put_events(events)
    |> reset()
  end
end

defmodule Mu.World.Arena.CooldownTimer do
  import Mu.World.Arena.Timer.Helpers
  alias Mu.World.Arena.Timer.TimerEvent

  def call(_context, timer) do
    event = %TimerEvent{
      pid: get_target(timer),
      topic: "cooldown/over",
      data: %{skill_id: timer.data.skill_id}
    }

    timer
    |> put_events(event)
    |> reset()
  end
end

defmodule Mu.World.Arena.RegenTimer do
  import Mu.World.Arena.Timer.Helpers
  alias Mu.World.Arena.Timer.TimerEvent

  def call(context, timer) do
    events =
      Enum.map(context.characters, fn character ->
        %TimerEvent{
          pid: character.pid,
          topic: "combat/regen",
          data: %{}
        }
      end)

    timer
    |> put_events(events)
    |> reset()
  end
end

defmodule Mu.World.Arena.VariableTimer do
  @moduledoc """
  A timer that has a %chance to fire when called
  Chance is either fixed or can increase each call
  """
  defstruct [:counter, :counter_max, :counter_max_increase, :event_data]

  import Mu.World.Arena.Timer.Helpers
  alias Mu.World.Arena.Timer.TimerEvent

  def call(context, timer) do
    timer =
      case timer.data.counter_max_increase > 0 do
        true ->
          increase = Enum.random(1..timer.data.counter_max_increase)
          new_counter = timer.data.counter + increase
          %{timer | data: Map.put(timer.data, :counter, new_counter)}

        false ->
          timer
      end

    case Enum.random(1..timer.data.counter_max) <= timer.data.counter do
      true -> fire(context, timer)
      false -> reset(timer)
    end
  end

  defp fire(context, timer) do
    events =
      Enum.map(get_targets(context, timer), fn target ->
        %TimerEvent{
          pid: target.pid,
          topic: timer.data.event_data.topic,
          data: Map.delete(timer.data.event_data, :topic)
        }
      end)

    data = Map.put(timer.data, :counter, 0)

    timer
    |> Map.put(:data, data)
    |> put_events(events)
    |> reset()
  end
end
