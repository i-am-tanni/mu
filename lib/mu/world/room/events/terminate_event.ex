defmodule Mu.World.Room.TerminateEvent do
  def call(_, _), do: Process.exit(self(), :normal)
end
