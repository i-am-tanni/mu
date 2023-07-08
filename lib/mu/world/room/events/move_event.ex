defmodule Mu.World.Room.MoveEvent do
  def call(context, %{data: notice}) when context.data.arena? do
    case notice.data do
      %Kalevala.Event{} = embedded_event -> Mu.World.Room.event(context, embedded_event)
      _ -> context
    end
  end

  def call(context, _event) do
    context
  end
end
