defmodule GolfWeb.GameController do
  use GolfWeb, :controller

  alias Golf.{Game, GameServer, GameSupervisor}

  def create_game(conn, _params) do
    %{"session_id" => session_id, "username" => username} = session = get_session(conn)

    if game_id = session["game_id"] do
      GameServer.remove_player(game_id, session_id)
    end

    game_id = Golf.gen_game_id()
    player = Game.Player.new(session_id, username)
    game = Game.new(game_id, player)

    {:ok, _pid} = DynamicSupervisor.start_child(GameSupervisor, {GameServer, game})

    conn
    |> put_session(:game_id, game_id)
    |> redirect(to: "/game/#{game_id}")
  end
end
