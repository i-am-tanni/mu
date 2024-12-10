defmodule Mu.Character.ConfirmView do
  use Kalevala.Character.View

  def render("prompt", %{prompt: prompt}) do
    [
      ~i(#{prompt}\n),
      ~i(\(Enter Y for yes or any other input for no\) >)
    ]
  end
end

defmodule Mu.Character.ConfirmController do
  use Kalevala.Character.Controller
  alias Mu.Character.ConfirmView

  @moduledoc """
  Controller for responding to a yes/no prompt.
  """

  @impl true
  def init(conn) do
    conn
    |> assign(:prompt, get_flash(conn, :prompt))
    |> render(ConfirmView, "prompt")
  end

  @doc """
  Wrapper function that prepares the data for the controller before it adds the controller

  The callback_fun is called on exit of this controller and accepts a bool as argument.
  """
  def put(conn, prompt, callback_fun) do
    flash = %{prompt: prompt, callback: callback_fun}
    Kalevala.Character.Conn.put_controller(conn, __MODULE__, flash)
  end

  @impl true
  def event(conn, _), do: conn

  @impl true
  def recv(conn, data) do
    callback_fun = get_flash(conn, :callback)

    data
    |> parse()
    |> callback_fun.()
  end

  def parse(<<?Y, _::binary>>), do: true
  def parse(_), do: false

end
