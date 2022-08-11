defmodule GolfWeb.PageController do
  use GolfWeb, :controller

  def index(conn, _params) do
    session = get_session(conn)

    render(conn, "index.html",
      username: session["username"],
      game_id: session["game_id"]
    )
  end
end
