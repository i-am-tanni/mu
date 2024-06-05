defmodule Mu.Character.LoginController do
  @moduledoc """
  Sign into your account

  If the account is not found, will transfer you to registration optionally
  """

  use Kalevala.Character.Controller
  alias Mu.Character.LoginView
  alias Mu.Character.CharacterController

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
    case get_flash(conn, :login_state) do
      :login -> process_username(conn, data)
    end
  end

  def process_username(conn, username) do
    username = String.trim(username)

    case username do
      "" -> render(conn, LoginView, "username")
      <<4>> -> halt(conn)
      "quit" -> halt(conn)
      username -> put_controller(conn, CharacterController, %{username: username})
    end
  end
end
