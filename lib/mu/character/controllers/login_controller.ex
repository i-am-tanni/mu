defmodule Mu.Character.LoginController do
  @moduledoc """
  Sign into your account

  If the account is not found, will transfer you to registration optionally
  """

  use Kalevala.Character.Controller
  alias Mu.Character.LoginView

  @impl true
  def init(conn) do
    conn
    |> put_flash(:login_state, :login)
    |> render(LoginView, "welcome")
    |> render(LoginView, "username")
  end

  @impl true
  def recv(conn, ""), do: conn

  @impl true
  def recv(conn, data) do
    conn
    |> assign(:data, data)
    |> render(LoginView, "echo")
  end
end
