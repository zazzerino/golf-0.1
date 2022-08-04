defmodule GolfWeb.GameController do
  use GolfWeb, :controller

  alias Golf.{Game, GameServer, GameSupervisor}
  alias Game.Player

  def create_game(conn, _params) do
    %{"session_id" => session_id, "username" => username} = session = get_session(conn)

    if game_id = session["game_id"] do
      GameServer.remove_player(game_id, session_id)
    end

    game_id = GameServer.gen_game_id()
    player = Player.new(session_id, username)
    game = Game.new(game_id, player)

    {:ok, _pid} = DynamicSupervisor.start_child(GameSupervisor, {GameServer, game})

    conn
    |> put_session(:game_id, game_id)
    |> redirect(to: Routes.live_path(conn, GolfWeb.GameLive, game_id))
  end

  def leave_game(conn, _params) do
    session = get_session(conn)

    if game_id = session["game_id"] do
      GameServer.remove_player(game_id, session["session_id"])
    end

    conn
    |> delete_session(:game_id)
    |> redirect(to: Routes.page_path(conn, :index))
  end

  def join_game(conn, %{"join_game" => %{"game_id" => game_id}}) do
    game_id = String.upcase(game_id, :ascii)

    if pid = GameServer.lookup_game_pid(game_id) do
      %{"session_id" => session_id, "username" => username} = get_session(conn)
      player = Player.new(session_id, username)
      GameServer.add_player(pid, player)

      conn
      |> put_session(:game_id, game_id)
      |> redirect(to: Routes.live_path(conn, GolfWeb.GameLive, game_id))
    else
      conn
      |> put_flash(:error, "Game #{game_id} not found.")
      |> redirect(to: Routes.page_path(conn, :index))
    end
  end
end
