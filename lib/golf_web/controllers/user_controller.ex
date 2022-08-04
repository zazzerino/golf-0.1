defmodule GolfWeb.UserController do
  use GolfWeb, :controller

  alias Golf.GameServer

  def update_name(conn, %{"user" => %{"name" => name}}) when is_binary(name) do
    %{"session_id" => session_id} = session = get_session(conn)

    if game_id = session["game_id"] do
      GameServer.update_player_name(game_id, session_id, name)
    end

    conn
    |> put_session(:username, name)
    |> put_flash(:info, "Name updated: #{name}")
    |> redirect(to: Routes.page_path(conn, :index))
  end

  def clear_session(conn, _params) do
    session = get_session(conn)

    if game_id = session["game_id"] do
      GameServer.remove_player(game_id, session["session_id"])
    end

    conn
    |> clear_session()
    |> configure_session(renew: true)
    |> put_flash(:info, "Session cleared")
    |> redirect(to: Routes.page_path(conn, :index))
  end
end
