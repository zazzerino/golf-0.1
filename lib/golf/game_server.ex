defmodule Golf.GameServer do
  use GenServer, restart: :transient

  require Logger

  alias Phoenix.PubSub
  alias Golf.{Game, GameRegistry}

  @max_players 4
  @inactivity_timeout 1000 * 60 * 30

  # Client

  def start_link(game) do
    GenServer.start_link(__MODULE__, game, name: via_tuple(game.id))
  end

  def fetch_state(pid) when is_pid(pid) do
    GenServer.call(pid, :fetch_state)
  end

  def fetch_state(id) when is_binary(id) do
    GenServer.call(via_tuple(id), :fetch_state)
  end

  def start_game(id, player_id) when is_binary(id) do
    GenServer.cast(via_tuple(id), {:start_game, player_id})
  end

  def add_player(pid, player) when is_pid(pid) do
    GenServer.cast(pid, {:add_player, player})
  end

  def add_player(id, player) when is_binary(id) do
    GenServer.cast(via_tuple(id), {:add_player, player})
  end

  def remove_player(id, player_id) when is_binary(id) do
    GenServer.cast(via_tuple(id), {:remove_player, player_id})
  end

  def handle_game_event(id, event) when is_binary(id) do
    GenServer.cast(via_tuple(id), {:game_event, event})
  end

  def update_player_name(id, player_id, new_name) when is_binary(id) do
    GenServer.cast(via_tuple(id), {:update_player_name, player_id, new_name})
  end

  def handle_chat_message(id, message) when is_binary(id) do
    GenServer.cast(via_tuple(id), {:chat_message, message})
  end

  def lookup_game_pid(game_id) do
    case Registry.lookup(GameRegistry, game_id) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  @spec gen_game_id() :: Game.id()
  def gen_game_id() do
    if lookup_game_pid(id = Golf.gen_id()) do
      # name has already been registered, so we'll recur and try again
      gen_game_id()
    else
      # name hasn't been registered, so we'll return it
      id
    end
  end

  defp via_tuple(id) when is_binary(id) do
    {:via, Registry, {GameRegistry, id}}
  end

  # Server

  @impl true
  def init(game) do
    {:ok, {game, set_timer(), []}}
  end

  @impl true
  def handle_call(:fetch_state, _from, {game, _timer, _messages} = state) do
    {:reply, {:ok, game}, state}
  end

  @impl true
  def handle_cast({:start_game, player_id}, {game, timer, messages})
      when player_id == game.host_id and game.state == :not_started do
    game = Game.start(game)
    broadcast_game_state(game)
    {:noreply, {game, reset_timer(timer), messages}}
  end

  @impl true
  def handle_cast({:add_player, player}, {game, timer, messages} = state) do
    player_ids = Game.player_ids(game)

    if player.id in player_ids or length(player_ids) >= @max_players do
      {:noreply, state}
    else
      game = Game.add_player(game, player)
      broadcast_game_state(game)
      {:noreply, {game, reset_timer(timer), messages}}
    end
  end

  @impl true
  def handle_cast({:remove_player, player_id}, {game, timer, messages} = state) do
    if player_id in Game.player_ids(game) do
      game = Game.remove_player(game, player_id)
      broadcast_game_state(game)

      if Enum.empty?(game.players) do
        Logger.info("Game #{game.id} was ended because all players left")
        broadcast_game_inactive(game.id)
        {:stop, :normal, state}
      else
        {:noreply, {game, reset_timer(timer), messages}}
      end
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:game_event, event}, {game, timer, messages} = state) do
    if game.state == :flip_two or Game.is_players_turn?(game, event.player_id) do
      case Game.handle_event(game, event) do
        {:ok, game} ->
          broadcast_game_state(game)
          {:noreply, {game, reset_timer(timer), messages}}

        _ ->
          {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:update_player_name, player_id, new_name}, {game, timer, messages}) do
    game = Game.update_player_name(game, player_id, new_name)
    broadcast_game_state(game)
    {:noreply, {game, reset_timer(timer), messages}}
  end

  @impl true
  def handle_cast({:chat_message, message}, {game, timer, messages}) do
    PubSub.broadcast(Golf.PubSub, "game:#{game.id}", {:chat_message, message})
    {:noreply, {game, reset_timer(timer), [message | messages]}}
  end

  @impl true
  def handle_info(:inactivity_timeout, {game, _timer, _messages} = state) do
    Logger.info("Game #{game.id} was ended for inactivity")
    broadcast_game_inactive(game.id)
    {:stop, :normal, state}
  end

  defp set_timer() do
    Process.send_after(self(), :inactivity_timeout, @inactivity_timeout)
  end

  defp reset_timer(timer) do
    Process.cancel_timer(timer)
    set_timer()
  end

  defp broadcast_game_state(game) do
    PubSub.broadcast(Golf.PubSub, "game:#{game.id}", {:game_state, game})
  end

  defp broadcast_game_inactive(game_id) do
    PubSub.broadcast(Golf.PubSub, "game:#{game_id}", :game_inactive)
  end
end
