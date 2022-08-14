defmodule GolfWeb.GameLive do
  use GolfWeb, :live_view

  alias Golf.{Game, GameServer}
  alias Game.Player

  @svg_width 500
  @svg_height 500
  @svg_viewbox "#{-@svg_width / 2}, #{-@svg_height / 2}, #{@svg_width}, #{@svg_height}"

  @card_width 60
  @card_height 84
  @card_scale "12%"

  @impl true
  def mount(params, session, socket) do
    %{"session_id" => session_id, "username" => username} = session
    game_id = params["game_id"]

    socket =
      assign(socket,
        session_id: session_id,
        username: username,
        svg_viewbox: @svg_viewbox,
        game_id: game_id,
        game: nil,
        players: [],
        table_card_0: nil,
        table_card_1: nil,
        playable_cards: [],
        last_event: nil,
        last_action: nil,
        last_event_pos: nil,
        not_started?: nil,
        draw_table_cards_first?: nil,
        can_start_game?: nil,
        can_join_game?: nil,
        trigger_join_game?: false,
        trigger_leave_game?: false,
        chat_messages: [],
        user_is_playing?: nil
      )

    if connected?(socket) and is_binary(game_id) do
      Phoenix.PubSub.subscribe(Golf.PubSub, "game:#{game_id}")
      send(self(), {:load_game, game_id})
    end

    {:ok, socket}
  end

  defp assign_game_data(socket, game) do
    session_id = socket.assigns.session_id

    player_ids = Game.player_ids(game)
    user_is_playing? = session_id in player_ids

    players = player_views(game.players, session_id, user_is_playing?)
    playable_cards = Game.playable_cards(game, session_id)

    last_event = Enum.at(game.events, 0)
    last_action = if last_event, do: last_event.action

    last_event_pos =
      if last_event do
        last_player = Enum.find(players, & &1.id == last_event.player_id)
        last_player.position
      end

    table_card_0 = Enum.at(game.table_cards, 0)
    table_card_1 = Enum.at(game.table_cards, 1)
    draw_table_cards_first? = last_action in [:take_from_deck, :take_from_table]

    not_started? = game.state == :not_started
    can_start_game? = not_started? and session_id == game.host_id
    can_join_game? = not_started? and not user_is_playing?

    assign(socket,
      game: game,
      players: players,
      table_card_0: table_card_0,
      table_card_1: table_card_1,
      draw_table_cards_first?: draw_table_cards_first?,
      playable_cards: playable_cards,
      last_event: last_event,
      last_action: last_action,
      last_event_pos: last_event_pos,
      not_started?: not_started?,
      can_start_game?: can_start_game?,
      can_join_game?: can_join_game?,
      user_is_playing?: user_is_playing?
    )
  end

  @impl true
  def handle_info({:load_game, game_id}, socket) do
    if pid = GameServer.lookup_game_pid(game_id) do
      {:ok, game, messages} = GameServer.fetch_state(pid)

      socket =
        socket
        |> assign_game_data(game)
        |> assign(:chat_messages, messages)

      {:noreply, socket}
    else
      socket = assign(socket, trigger_leave_game?: true)
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:game_state, game}, socket) do
    socket = assign_game_data(socket, game)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:game_inactive, socket) do
    socket = assign(socket, trigger_leave_game?: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:chat_message, message}, socket) do
    messages = [message | socket.assigns.chat_messages]
    {:noreply, assign(socket, chat_messages: messages)}
  end

  @impl true
  def handle_event("start_game", _, socket) do
    %{session_id: session_id, game_id: game_id} = socket.assigns
    GameServer.start_game(game_id, session_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("join_game", _, socket) do
    socket = assign(socket, trigger_join_game?: true)
    {:noreply, socket}
  end

  @impl true
  def handle_event("deck_click", value, socket) do
    if Map.has_key?(value, "playable") do
      %{session_id: session_id, game_id: game_id} = socket.assigns
      event = Game.Event.new(:take_from_deck, session_id)
      GameServer.handle_game_event(game_id, event)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("table_click", value, socket) do
    if Map.has_key?(value, "playable") do
      %{session_id: session_id, game_id: game_id} = socket.assigns
      event = Game.Event.new(:take_from_table, session_id)
      GameServer.handle_game_event(game_id, event)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("held_click", value, socket) do
    if Map.has_key?(value, "playable") do
      %{session_id: session_id, game_id: game_id} = socket.assigns
      event = Game.Event.new(:discard, session_id)
      GameServer.handle_game_event(game_id, event)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("hand_click", value, socket) do
    %{session_id: session_id, playable_cards: playable_cards} = socket.assigns

    player_id = value["player-id"] |> String.to_integer()
    index = value["index"] |> String.to_integer()
    card = String.to_existing_atom("hand_#{index}")

    if session_id == player_id and card in playable_cards do
      game = socket.assigns.game

      case game.state do
        s when s in [:flip_two, :flip] ->
          unless Map.has_key?(value, "face-up") do
            event = Game.Event.new(:flip, session_id, %{index: index})
            GameServer.handle_game_event(game.id, event)
          end

        :hold ->
          event = Game.Event.new(:swap, session_id, %{index: index})
          GameServer.handle_game_event(game.id, event)
      end
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("send_chat_message", value, socket) do
    case value["chat"]["text"] do
      "" ->
        {:noreply, socket}

      text when is_binary(text) ->
        %{session_id: session_id, username: username, game_id: game_id} = socket.assigns
        message = Golf.ChatMessage.new(session_id, username, text)
        GameServer.handle_chat_message(game_id, message)
        {:noreply, socket}
    end
  end

  ## Component Helpers

  defp card_scale, do: @card_scale

  defp card_center_x, do: -@card_width / 2
  defp card_center_y, do: -@card_height / 2

  defp deck_x(:not_started), do: card_center_x()
  defp deck_x(_), do: card_center_x() - @card_width / 2

  defp deck_y, do: card_center_y()

  defp table_card_x, do: 0
  defp table_card_y, do: card_center_y()

  defp hand_card_x(index) do
    case index do
      i when i in [0, 3] -> -@card_width * 1.5
      i when i in [1, 4] -> -@card_width / 2
      i when i in [2, 5] -> @card_width / 2
    end
  end

  defp hand_card_y(index) do
    case index do
      i when i in 0..2 -> -@card_height
      _ -> 0
    end
  end

  defp hand_card_playable?(session_id, player_id, playable_cards, index) do
    if session_id == player_id do
      card = String.to_existing_atom("hand_#{index}")
      card in playable_cards
    end
  end

  defp hand_positions(num_players) do
    case num_players do
      1 -> [:bottom]
      2 -> [:bottom, :top]
      3 -> [:bottom, :left, :right]
      4 -> [:bottom, :left, :top, :right]
    end
  end

  defp rotate(list, n) do
    list
    |> Stream.cycle()
    |> Stream.drop(n)
    |> Stream.take(length(list))
    |> Enum.to_list()
  end

  defp player_view({position, player}) do
    player
    |> Map.put(:position, position)
    |> Map.put(:score, Player.score(player))
  end

  # If the user is playing, we'll rotate the players so the user is on bottom.
  defp player_views(players, session_id, _user_is_playing? = true) do
    positions = hand_positions(length(players))
    user_index = Enum.find_index(players, &(&1.id == session_id))
    players = rotate(players, user_index)

    Enum.zip(positions, players)
    |> Enum.map(&player_view/1)
  end

  # Otherwise, we'll draw the host on bottom.
  defp player_views(players, _, _) do
    positions = hand_positions(length(players))

    Enum.zip(positions, players)
    |> Enum.map(&player_view/1)
  end

  ## Components

  def card_image(assigns) do
    highlight = if assigns[:highlight], do: "highlight"

    assigns =
      assign(assigns,
        class: "card #{assigns[:class]} #{highlight}",
        extra: assigns_to_attributes(assigns, [:class, :name, :x, :y, :highlight])
      )

    ~H"""
    <image
      class={@class}
      href={"/images/cards/#{@name}.svg"}
      x={@x}
      y={@y}
      width={card_scale()}
      {@extra}
    />
    """
  end

  def deck(assigns) do
    animation = if assigns[:state] == :not_started, do: "float-from-top"
    assigns = assign(assigns, class: "deck #{animation}")

    ~H"""
    <.card_image
      class={@class}
      name="2B"
      x={deck_x(@state)}
      y={deck_y()}
      highlight={@playable}
      phx-value-playable={@playable}
      phx-click="deck_click"
    />
    """
  end

  def table_card_0(assigns) do
    animation =
      case assigns[:last_action] do
        :discard ->
          pos = assigns.last_event_pos
          "slide-from-held-#{pos}"

        :swap ->
          pos = assigns.last_event_pos
          index = assigns.last_event.data.index
          "slide-from-hand-#{index}-#{pos}"

        _ ->
          nil
      end

    assigns = assign(assigns, class: "table #{animation}")

    ~H"""
    <.card_image
      class={@class}
      name={@name}
      x={table_card_x()}
      y={table_card_y()}
      highlight={@playable}
      phx-value-playable={@playable}
      phx-click="table_click"
    />
    """
  end

  def table_card_1(assigns) do
    ~H"""
    <.card_image
      class={"table-1"}
      name={@name}
      x={table_card_x()}
      y={table_card_y()}
    />
    """
  end

  def table_cards(assigns) do
    ~H"""
    <%= if @table_card_1 do %>
      <.table_card_1 name={@table_card_1} />
    <% end %>

    <%= if @table_card_0 do %>
      <.table_card_0
        name={@table_card_0}
        playable={:table in @playable_cards}
        last_event={@last_event}
        last_action={@last_action}
        last_event_pos={@last_event_pos}
      />
    <% end %>
    """
  end

  def hand(assigns) do
    ~H"""
    <g class={"hand #{@position}"}>
      <%= for {{card, face_up?}, index} <- Enum.with_index(@cards) do %>
        <.card_image
          class={"hand-card hand-#{index}"}
          name={if face_up?, do: card, else: "2B"}
          x={hand_card_x(index)}
          y={hand_card_y(index)}
          highlight={hand_card_playable?(@session_id, @player_id, @playable_cards, index)}
          phx-value-index={index}
          phx-value-player-id={@player_id}
          phx-value-face-up={face_up?}
          phx-click="hand_click"
        />
      <% end %>
    </g>
    """
  end

  def held_card(assigns) do
    animation =
      case assigns[:last_action] do
        :take_from_deck -> "slide-from-deck"
        :take_from_table -> "slide-from-table"
        _ -> nil
      end

    class = "held #{assigns[:position]} #{animation}"
    assigns = assign(assigns, class: class)

    ~H"""
    <.card_image
      class={@class}
      name={@name}
      x={card_center_x()}
      y={card_center_y()}
      highlight={@playable}
      phx-value-playable={@playable}
      phx-click="held_click"
    />
    """
  end

  defp format_datetime(dt) do
    dt
    |> DateTime.to_time()
    |> Time.truncate(:second)
    |> Time.to_string()
  end

  def chat_message(assigns) do
    ~H"""
    <div class="chat-message">
      <span class="chat-sent-at">
        <%= format_datetime(@sent_at) %>
      </span>

      <span class="chat-username">
        <%= @username %>:
      </span>

      <span class="chat-text">
        <%= @text %>
      </span>
    </div>
    """
  end

  def chat(assigns) do
    ~H"""
    <div class="chat">
      <div class="chat-messages">
        <%= for message <- @messages do %>
          <.chat_message
            username={message.username}
            text={message.text}
            sent_at={message.sent_at}
          />
        <% end %>
      </div>
      
      <.form let={f} for={:chat} phx-submit="send_chat_message">
        <%= text_input f, :text, placeholder: "Type chat message" %>
        <%= submit "Send" %>
      </.form>
    </div>
    """
  end
end
