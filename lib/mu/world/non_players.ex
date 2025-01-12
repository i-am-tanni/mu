defmodule Mu.World.NonPlayers do
  @moduledoc """
  Cache for non-player character prototypes
  """

  use Kalevala.Cache
end

defmodule Mu.World.NonPlayerRegistry do
  @moduledoc """
  Registry for tracking mobile pids
  """

  use Kalevala.Cache

  def register(id, pid) do
    put(id, pid)
    put(pid, id)
    Process.monitor(pid)
  end

  def registered?(id) do
    case get(id) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}) do
    case reason in [:normal, :shutdown] && get(pid) do
      {:ok, id} ->
        delete(id)
        delete(pid)

      _ ->
        nil
    end
  end
end
