defmodule Mu.World.Room.CombatEvent do
  import Kalevala.World.Room.Context
  import Mu.Utility

  alias Mu.Character

  @doc """
  Check if combat is allowed in room and if so, ask the victims to confirmed they can be attacked.
  """
  def request(context, event) do
    with :ok <- consider(context, event),
         {:ok, victims} <- find_victims(context, event) |> if_err("not-found") do
      data = %{event.data | attacker: event.acting_character}
      broadcast(context, "combat/request", data, to: victims)
    else
      {:error, reason} ->
        event(context, event.acting_character.pid, self(), "combat/error", %{reason: reason})
    end
  end

  def abort(context, event) do
    event(context, event.attacker.id, self(), "combat/error", %{reason: event.data.reason})
  end

  defp consider(_context, _event) do
    :ok
  end

  defp find_victims(context, event) do
    case event.data.victims do
      victims when is_list(victims) ->
        Enum.filter(context.characters, fn character ->
          Enum.any?(victims, &Character.matches?(character, &1))
        end)

      victim ->
        context.characters
        |> Enum.find(&Character.matches?(&1, victim))
        |> List.wrap()
    end
  end
end

defmodule Mu.World.Room.CombatRoundEvent do
  @moduledoc """
  Events pertaining to cyclical combat rounds.
  Round actions are received by participants and fired off at the end of the round
  """

  import Kalevala.World.Room.Context

  @round_length_ms 3000
  @max_speed 1000

  @doc """
  Push event into a queue to be fired off at the end of a round
  If in process, prioritize the round action and put it into a queue to be added to the next round.
  If the round is NOT in process and the round_queue is empty, schedule the next round
  """

  def push(context, event) when context.data.round_in_process? do
    # assume late event and give it priority next round
    data = %{event.data | speed: @max_speed, attacker: event.acting_character}
    event = Map.put(event, :data, data)
    next_round_queue = context.data.next_round_queue
    put_data(context, :next_round_queue, [event | next_round_queue])
  end

  def push(context, event) do
    data = %{event.data | attacker: event.acting_character}
    event = Map.put(event, :data, data)
    round_queue = context.data.round_queue
    if Enum.empty?(round_queue), do: schedule()
    put_data(context, :round_queue, [event | round_queue])
  end

  @doc """
  If the round is not in process, initialize the round. Otherwise, pop the next event in the queue
  The reason all round events are fired off one by one is so events can be:
    - reacted to (e.g. parries)
    - cancelled in the event that the victim is incapcitated or dies
  """
  def pop(context, _) when context.data.round_in_process? do
    case context.data.round_queue do
      [head | rest] ->
        # send round request
        victim = find_victim(context, head)

        context =
          case !is_nil(victim) do
            true ->
              event(context, victim.pid, self(), "round/request", head.data)

            false ->
              data = %{reason: "not_found"}
              event(context, head.acting_character.pid, self(), "combat/error", data)
          end

        put_data(context, :round_queue, rest)

      [] ->
        # complete round
        next_round_queue = context.data.next_round_queue
        if !Enum.empty?(next_round_queue), do: schedule()

        context
        |> put_data(:round_queue, next_round_queue)
        |> put_data(:next_round_queue, [])
        |> put_data(:round_in_process?, false)
        |> broadcast("round/end", %{})
    end
  end

  def pop(context, event), do: kickoff(context, event)

  defp kickoff(context, event) do
    sorted = Enum.sort(context.data.round_queue, &(&1.data.speed >= &2.data.speed))

    context
    |> put_data(:round_in_process?, true)
    |> put_data(:round_queue, sorted)
    |> pop(event)
  end

  defp schedule() do
    now = Time.utc_now()
    now_in_ms = now.second * 1000 + div(elem(now.microsecond, 0), 1000)

    delay = @round_length_ms - rem(now_in_ms, @round_length_ms)

    event = %Kalevala.Event{topic: "round/pop", from_pid: self(), data: %{}}
    Process.send_after(self(), event, delay)
  end

  defp find_victim(context, event) do
    victim_id = event.data.victims.id

    Enum.find(context.characters, fn character ->
      Mu.Character.matches?(character, victim_id)
    end)
  end
end

defmodule Mu.World.Room.CombatCancel do
  import Kalevala.World.Room.Context

  def call(context, event) do
    victim_id = event.data.victim.id

    round_queue =
      Enum.reject(context.data.round_queue, fn event ->
        event.acting_character.id == victim_id or
          event.data.victim.id == victim_id
      end)

    put_data(context, :round_queue, round_queue)
  end
end
