defmodule Mu.World.Room.CombatEvent do
  import Kalevala.World.Room.Context

  alias Mu.Character

  @doc """
  Check if combat is allowed in room and if so, ask the victims to confirmed they can be attacked.
  """

  def request(context, event) when event.data.round_based? do
    # fix topic and re-route
    event = %{event | topic: "round/push"}
    Mu.World.Room.CombatRoundEvent.push(context, event)
  end

  def request(context, event) do
    with :ok <- consider(context, event),
         {:ok, victims} <- find_victims(context, event) do
      data = %{event.data | attacker: event.acting_character}
      broadcast(context, "combat/request", data, to: victims)
    else
      {:error, reason} ->
        event(context, event.from_pid, self(), "combat/abort", %{reason: reason})
    end
  end

  def abort(context, event) do
    event(context, event.attacker.id, self(), "combat/abort", %{reason: event.data.reason})
  end

  @doc """
  Victim has already commited the request by this point to prevent race conditions.
  Announce commit to attacker and any witnesses in the room.
  """
  def commit(context, event) do
    victim = event.acting_character
    victim_id = victim.id

    recipients = Enum.reject(context.characters, &Character.matches?(&1, victim_id))

    context
    |> broadcast(event.topic, event.data, to: recipients)
    |> update_character(victim)
  end

  def flee(context, event) do
    victim_id = event.acting_character.id
    recipients = Enum.reject(context.characters, &Character.matches?(&1, victim_id))
    broadcast(context, event.topic, event.data, to: recipients)
  end

  defp consider(_context, _event) do
    :ok
  end

  defp find_victims(context, %{data: data = %{victims: victims}}) when is_list(victims) do
    result =
      Enum.filter(context.characters, fn character ->
        Enum.any?(victims, &Character.matches?(character, &1))
      end)
      |> Enum.take(data.target_count)

    case result != [] do
      true -> {:ok, result}
      false -> {:error, "not-found"}
    end
  end

  defp find_victims(_, event) do
    raise("Combat request received where victims is not a list: #{inspect(event)}")
  end
end

defmodule Mu.World.Room.CombatRoundEvent do
  @moduledoc """
  Events pertaining to cyclical combat rounds.
  Round actions are received by participants and fired off at the end of the round
  """

  import Kalevala.World.Room.Context

  alias Mu.Character

  @round_length_ms 3000
  @max_speed 1000

  @doc """
  Push event into a queue to be fired off at the end of a round
  If in process, prioritize the round action and put it into a queue to be added to the next round.
  If the round is NOT in process and the round_queue is empty, schedule the next round
  """

  def push(context, event) when context.data.round_in_process? do
    # assume late event and give it priority next round by overriding speed to max
    data = %{event.data | speed: @max_speed}
    event = Map.put(event, :data, data)
    next_round_queue = context.data.next_round_queue
    put_data(context, :next_round_queue, [event | next_round_queue])
  end

  def push(context, event) do
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
        context
        |> forward(head)
        |> put_data(:round_queue, rest)

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

  def death(context, event) do
    context
    |> cancel(event)
    |> broadcast(event.topic, event.data)
  end

  @doc """
  Cancels any pending round events from the acting character
  """
  def cancel(context, event) do
    id = event.acting_character.id

    round_queue =
      Enum.reject(context.data.round_queue, fn event ->
        event.acting_character.id == id
      end)

    next_round_queue =
      Enum.reject(context.data.next_round_queue, fn event ->
        event.acting_character.id == id
      end)

    context
    |> put_data(:round_queue, round_queue)
    |> put_data(:next_round_queue, next_round_queue)
  end

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

  defp forward(context, event) do
    with {:ok, victims} <- find_victims(context, event),
         {:ok, attacker} <- find_attacker(context, event) do
      # We need to update attacker's info b/c the event was sent in advance of possible round effects
      # Any possible commits that have updated attacker's vitals
      # But also pass along the attacker's most up to date in_combat? status
      meta = %{attacker.meta | in_combat?: event.acting_character.meta.in_combat?}
      data = %{event.data | attacker: %{attacker | meta: meta}}

      Enum.reduce(victims, context, fn victim, acc ->
        event(acc, victim.pid, self(), "combat/request", data)
      end)
    end
  end

  defp find_victims(context, %{data: data = %{victims: victims}}) when is_list(victims) do
    result =
      Enum.filter(context.characters, fn character ->
        Enum.any?(victims, &Character.matches?(character, &1))
      end)
      |> Enum.take(data.target_count)

    case result != [] do
      true ->
        {:ok, result}

      false ->
        event(context, self(), self(), "round/pop", %{})
    end
  end

  defp find_victims(_, event) do
    raise("Combat request received where victims is not a list: #{inspect(event)}")
  end

  defp find_attacker(context, event) do
    id = event.acting_character.id

    result =
      Enum.find(context.characters, fn character ->
        Character.matches?(character, id)
      end)

    case !is_nil(result) do
      true ->
        {:ok, result}

      false ->
        context
        |> cancel(event)
        |> event(self(), self(), "round/pop", %{})
    end
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
