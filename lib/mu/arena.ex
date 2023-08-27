defmodule Mu.World.Arena.Damage do
  defstruct [:type, :verb, :amount]
end

defmodule Mu.World.Arena.Team do
  defstruct members: []
end

defmodule Mu.World.Arena.TurnData do
  defstruct [:id, :character_id, :pid, :ap, :speed, :turn_threshold]
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

defmodule Mu.World.Arena.SpeedModTimer do
  alias Mu.World.Arena.TurnData

  defstruct [:id, :character_id, :ap, :speed, :turn_threshold]

  def init(turn_timer = %TurnData{}, speed_mod_timer)
      when turn_timer.character_id == speed_mod_timer.character_id do
    %{turn_timer | speed: turn_timer.speed + speed_mod_timer.speed}
  end

  def call(turn_timer = %TurnData{}, speed_mod_timer)
      when turn_timer.character_id == speed_mod_timer.character_id do
    %{turn_timer | speed: turn_timer.speed + speed_mod_timer.speed}
  end
end

defmodule Mu.World.Arena.Turn do
  @moduledoc """
  Module for advancing turns
  """

  import Kalevala.World.Room.Context
  import Mu.World.Arena.Context

  alias Mu.World.Arena.Timer
  alias Mu.World.Arena.TurnData
  alias Mu.World.Arena.SpeedModTimer

  @doc """
  Advances timers until one completes.

  Once completed,
  """
  def next(context, opts \\ %{})

  def next(context, opts) when context.data.arena_data.on_turn_characters == [] do
    timers = Map.get(opts, :timers, get_arena_data(context, :turn_list))
    tic_count = Map.get(opts, :tic_count, 0)

    {timers, tics} = tic_til_turn(timers)

    tic_count = tic_count + tics

    expired_timers =
      timers
      |> Enum.filter(fn x -> x.ap >= x.turn_threshold end)
      |> Enum.reduce(%{}, fn timer, acc ->
        module = timer.__struct__
        list = Map.get(acc, module, [])
        Map.put(acc, module, [timer | list])
      end)

    expired_speed_modifiers = Map.get(expired_timers, SpeedModTimer, [])

    timers =
      case expired_speed_modifiers != [] do
        true -> remove_speed_modifiers(timers, expired_speed_modifiers)
        false -> timers
      end

    on_turn_characters = Map.get(expired_timers, TurnData, [])
    on_turn_characters = Enum.sort(on_turn_characters, &(&1.ap >= &2.ap))

    case on_turn_characters != [] do
      true ->
        context
        |> put_arena_data(:turn_list, timers)
        |> put_arena_data(:tic_count, tic_count)
        |> activate_character(on_turn_characters, tic_count)

      false ->
        next(context, %{timers: timers, tic_count: tic_count})
    end
  end

  def next(context, _) do
    on_turn_characters = get_arena_data(context, :on_turn_characters)
    tic_count = get_arena_data(context, :tic_count)
    activate_character(context, on_turn_characters, tic_count)
  end

  def tic(list, count) do
    Enum.reduce(1..count, list, fn _, list ->
      Enum.map(list, fn x -> Map.put(x, :ap, x.ap + x.speed) end)
    end)
  end

  # remove effect of a speed modifier after expiration
  defp remove_speed_modifiers(timers, expired_speed_modifiers) do
    timers
    |> Enum.reject(fn %{id: id} ->
      Enum.any?(expired_speed_modifiers, &(&1.id == id))
    end)
    |> Enum.map(fn %{character_id: character_id} = timer ->
      mods = Enum.find(expired_speed_modifiers, &(&1.character_id == character_id))

      case !is_nil(mods) do
        true -> SpeedModTimer.call(timer, mods)
        false -> timer
      end
    end)
  end

  defp tic_til_turn(list, count \\ 1) do
    list = Enum.map(list, fn x -> Map.put(x, :ap, x.ap + x.speed) end)

    case !Enum.any?(list, fn x -> x.ap >= x.turn_threshold end) do
      true -> tic_til_turn(list, count + 1)
      false -> {list, count}
    end
  end

  defp activate_character(context, on_turn_characters, tic_count) do
    [active_character | on_turn_characters] = on_turn_characters
    IO.inspect(active_character, label: "<active_character>")

    merge_data = %{
      active_character: active_character,
      turn_notifications: 0,
      on_turn_characters: on_turn_characters
    }

    context
    |> merge_arena_data(merge_data)
    |> broadcast("turn/tics", %{tics: tic_count})
    |> event(active_character.pid, self(), "turn/notify", %{})
  end

  defp resolve_timers(context, timers) do
    timers
    |> Enum.filter(fn x -> x.ap >= x.turn_threshold end)
    |> Enum.reduce(context, fn timer, acc ->
      Timer.call(acc, timer)
    end)
  end

  defp broadcast(context, topic, data) do
    Enum.reduce(context.characters, context, fn character, acc ->
      event(acc, character.pid, self(), topic, data)
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
    :tic_count,
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
