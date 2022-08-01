defmodule GolfWeb.UserController do
  use GolfWeb, :controller

  def update_name(conn, %{"user" => %{"name" => name}}) when is_binary(name) do
    conn
    |> put_session(:username, name)
    |> put_flash(:info, "Name updated: #{name}")
    |> redirect(to: "/")
  end

  def clear_session(conn, _params) do
    session = get_session(conn)

    if game_id = session["game_id"] do
      Golf.GameServer.remove_player(game_id, session["session_id"])
    end

    conn
    |> clear_session()
    |> configure_session(renew: true)
    |> put_flash(:info, "Session cleared")
    |> redirect(to: "/")
  end
end
