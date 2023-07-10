defmodule Mu.World.Room.CombatEvent do
  @moduledoc """
  Combat is initiated via this event.
  """

  import Kalevala.World.Room.Context
  import Mu.World.Arena.Context

  alias Mu.World.Arena
  alias Mu.World.Room
  alias Mu.World.Exit
  alias Mu.World.Kickoff

  alias Mu.Character.LookView
  alias Mu.Character.CommandView

  def request(context, event) do
    text = event.data.text

    case !context.data.arena? and !context.data.peaceful? do
      true ->
        target = find_local_character(context, text)

        case !is_nil(target) do
          true ->
            data = %{attacker: event.acting_character}

            event(context, target.pid, self(), "combat/request", data)

          false ->
            context
            |> assign(:text, text)
            |> render(event.from_pid, LookView, "unknown")
            |> assign(:character, event.acting_character)
            |> render(event.from_pid, CommandView, "prompt")
        end

      false ->
        error =
          cond do
            context.data.arena? -> "room/arena"
            context.data.peaceful? -> "room/peaceful"
          end

        event(context, event.acting_character.pid, self(), error, %{})
    end
  end

  def commit(context, event) do
    params = %{
      origin_room: context.data.id,
      zone_id: context.data.zone_id,
      attackers: attackers = get_attackers(context, event),
      defenders: defenders = get_defenders(context, event)
    }

    arena = build_arena(params)
    {:ok, arena_pid} = Kickoff.start_room(arena)

    data = %{
      from: context.data.id,
      to: arena.id,
      attacker: event.data.attacker,
      victim: event.acting_character,
      participants: attackers ++ defenders
    }

    context
    |> event(arena_pid, self(), "arena/init", %{initial_events: []})
    |> broadcast(%{event | topic: "combat/commit", data: data})
  end

  def refuse(context, event) do
    event(context, event.data.attacker.pid, self(), "combat/abort", event.data)
  end

  def force_start_or_abort(context, event) when context.data.arena_data.status == :init do
    arena_data = context.data.arena_data
    attackers = arena_data.attackers.members
    defenders = arena_data.defenders.members

    case attackers != [] and defenders != [] do
      true ->
        context
        |> merge_arena_data(%{status: :running, waiting_for: []})
        |> Mu.World.Arena.Turn.next()

      false ->
        abort(context, event)
    end
  end

  def force_start_or_abort(context, _), do: context

  def abort(context, event) when context.data.arena? do
    terminate_event = %Kalevala.Event{
      topic: "room/terminate",
      from_pid: self(),
      data: %{}
    }

    Process.send_after(self(), terminate_event, 5000)

    context
    |> put_arena_data(:status, :terminating)
    |> broadcast(event, "combat/abort")
  end

  def abort(context, _event), do: context

  defp build_arena(params) do
    arena_id = Kalevala.Character.generate_id()

    exits = [
      %Exit{
        id: "flee",
        type: :normal,
        exit_name: "flee",
        start_room_id: arena_id,
        end_room_id: params.origin_room,
        hidden?: false,
        secret?: false,
        door: nil
      }
    ]

    %Room{
      arena?: true,
      id: arena_id,
      zone_id: params.zone_id,
      name: "You are fighting!",
      description: "You are in combat!",
      exits: exits,
      peaceful?: false,
      arena_data: build_arena_data(params)
    }
  end

  defp build_arena_data(params) do
    attackers = params.attackers
    defenders = params.defenders

    %Arena{
      active_character: nil,
      turn_notifications: 0,
      status: :init,
      waiting_for: Enum.map(attackers ++ defenders, & &1.id),
      on_turn_characters: [],
      turn_list: [],
      timers: [],
      attackers: struct(Mu.World.Arena.Team, members: attackers),
      defenders: struct(Mu.World.Arena.Team, members: defenders)
    }
  end

  defp get_attackers(_context, event) do
    [event.data.attacker]
  end

  defp get_defenders(_context, event) do
    [event.acting_character]
  end

  defp broadcast(context, event, topic_override \\ nil) do
    event =
      if topic_override,
        do: Map.put(event, :topic, topic_override),
        else: event

    Enum.reduce(context.characters, context, fn character, acc ->
      event(acc, character.pid, self(), event.topic, event.data)
    end)
  end

  defp find_local_character(context, name) do
    Enum.find(context.characters, fn character ->
      Mu.Character.matches?(character, name)
    end)
  end
end

defmodule Mu.World.Room.ArenaJoinEvent do
  import Kalevala.World.Room.Context
  import Mu.World.Arena.Context

  alias Mu.World.Arena.TurnData
  alias Mu.World.Arena.Turn

  def commit(context, event) when context.data.arena_data.status != :terminating do
    character = event.acting_character
    team = get_arena_data(context, event.data.team)
    team = %{team | members: [character | team.members]}
    turn_list = get_arena_data(context, :turn_list)
    turn_list = [turn_data(character) | turn_list]
    waiting_for = get_arena_data(context, :waiting_for)

    waiting_for =
      case waiting_for != [] and character.id in waiting_for do
        true -> Enum.reject(waiting_for, &(&1 == character.id))
        false -> waiting_for
      end

    merge_data = %{team: team, turn_list: turn_list, waiting_for: waiting_for}

    context = merge_arena_data(context, merge_data)

    case get_arena_data(context, :status) == :init and waiting_for == [] do
      true ->
        context
        |> put_arena_data(:status, :running)
        |> broadcast(%{event | data: %{}}, "room/look")
        |> Turn.next()

      false ->
        context
    end
  end

  defp turn_data(character) do
    %TurnData{
      id: character.id,
      pid: character.pid,
      ap: Map.get(character, :ap, 0),
      speed: Map.get(character, :speed, 100),
      turn_threshold: Map.get(character, :turn_threshold, 1000)
    }
  end

  defp broadcast(context, event, topic_override \\ nil) do
    event =
      if topic_override,
        do: Map.put(event, :topic, topic_override),
        else: event

    Enum.reduce(context.characters, context, fn character, acc ->
      event(acc, character.pid, self(), event.topic, event.data)
    end)
  end
end

defmodule Mu.World.Room.ArenaTurnEvent do
  @moduledoc """
  Combat actions are turn based in the Arena.
  This event processes turn requests.
  Turns typically go through three stages: notification, request, and commit.
  """

  import Kalevala.World.Room.Context
  import Mu.World.Arena.Context

  alias Mu.World.Arena.Turn
  alias Mu.World.Arena.CooldownTimer

  def request(context, event) do
    active_character = get_arena_data(context, :active_character)

    case active_character.id == event.acting_character.id do
      true -> _request(context, event)
      false -> event(context, event.acting_character.pid, self(), "turn/wait", %{})
    end
  end

  defp _request(context, event) do
    victim = find_victim(context, event)

    case !is_nil(victim) do
      true ->
        event = %{event | data: Map.put(event.data, :victim, victim)}
        event(context, event.data.victim.pid, self(), "turn/request", event.data)

      false ->
        event(context, event.acting_character.pid, self(), "target/invalid", %{})
    end
  end

  def commit(context, event) do
    active_character = get_arena_data(context, :active_character)

    case active_character.id == event.data.attacker.id do
      true ->
        context
        |> update_turn_data(event)
        |> update_timers(event)
        |> broadcast(event, "turn/commit")
        |> Turn.next()

      false ->
        event(context, event.acting_character.pid, self(), "turn/wait", event.data)
    end
  end

  defp review(context, event) do
    cooldown =
      get_arena_data(context, :timers)
      |> Enum.find(fn timer ->
        timer.callback_module == CooldownTimer and
          timer.owner == event.acting_charater.id and
          timer.data.skill_id == event.data.skill_id
      end)

    case is_nil(cooldown) do
      true ->
        approve(context, event)

      false ->
        time_left = cooldown.turn_threshold - cooldown.ap
        data = Map.merge(event.data, %{time_left: time_left, reason: :skill_on_cooldown})

        event(context, event.acting_character.pid, self(), "action/abort", data)
    end
  end

  defp approve(context, event) do
    event(context, event.data.victim.pid, self(), "turn/request", event.data)
  end

  defp update_turn_data(context, event) do
    turn_list = get_arena_data(context, :turn_list)
    attacker_id = event.data.attacker.id
    victim_id = event.data.victim.id

    turn_list =
      Enum.map(turn_list, fn
        %{id: ^attacker_id} = turn_data ->
          turn_cost = Map.get(event.data, :turn_cost, 1000)
          Map.put(turn_data, :ap, turn_data.ap - turn_cost)

        %{id: ^victim_id} = turn_data when attacker_id != victim_id ->
          hit_stun = Map.get(event.data, :hit_stun, 0)
          Map.put(turn_data, :ap, turn_data.ap - hit_stun)

        no_change ->
          no_change
      end)

    put_arena_data(context, :turn_list, turn_list)
  end

  defp update_timers(context, event) do
    timer_updates = Map.get(event.data, :timer_updates, [])
    timers = get_arena_data(context, :timers)

    timers =
      case timer_updates != [] do
        true ->
          Enum.map(get_arena_data(context, :timers), fn timer ->
            update = Enum.find(timer_updates, &(&1.owner == timer.owner))

            case !is_nil(update) do
              true -> Map.merge(timer, update)
              false -> timer
            end
          end)

        false ->
          timers
      end

    new_timers = Map.get(event.data, :timer_adds, [])
    put_arena_data(context, :timers, new_timers ++ timers)
  end

  defp find_victim(context, event) do
    case event.data.victim do
      :random ->
        attacker_id = event.acting_character.id

        context.characters
        |> Enum.reject(&(&1.id == attacker_id))
        |> Enum.random()

      text ->
        find_local_character(context, text)
    end
  end

  defp find_local_character(context, name) do
    Enum.find(context.characters, fn character ->
      Mu.Character.matches?(character, name)
    end)
  end

  defp broadcast(context, event, topic_override \\ nil) do
    event =
      if topic_override,
        do: Map.put(event, :topic, topic_override),
        else: event

    Enum.reduce(context.characters, context, fn character, acc ->
      event(acc, character.pid, self(), event.topic, event.data)
    end)
  end
end
