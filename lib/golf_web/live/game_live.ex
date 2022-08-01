defmodule GolfWeb.GameLive do
  use GolfWeb, :live_view

  @svg_width 500
  @svg_height 500
  @svg_viewbox "#{-@svg_width / 2}, #{-@svg_height / 2}, #{@svg_width}, #{@svg_height}"

  @card_width 60
  @card_height 84
  @card_scale "12%"

  @impl true
  def mount(params, session, socket) do
    %{"game_id" => game_id} = params
    %{"username" => username} = session

    socket = assign(socket, username: username, game_id: game_id, viewbox: @svg_viewbox)
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h2>Game <%= @game_id %></h2>

    <svg class="game-svg" viewBox={@viewbox}>
      <.card_image name="2B" />
    </svg>

    <footer>Logged in as <%= @username %></footer>
    """
  end

  # Components

  def card_image(assigns) do
    x = assigns[:x] || card_center_x()
    y = assigns[:y] || card_center_y()

    highlight = if assigns[:highlight], do: "highlight"
    class = "card #{assigns[:class]} #{highlight}" |> String.trim()
    extra = assigns_to_attributes(assigns, [:class, :card_name, :x, :y, :highlight])
    assigns = assign(assigns, x: x, y: y, class: class, extra: extra)

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

  # Helpers

  def card_scale, do: @card_scale
  def card_center_x, do: -@card_width / 2
  def card_center_y, do: -@card_height / 2

  def deck_x(_started? = true), do: card_center_x()
  def deck_x(_), do: card_center_x() - @card_width / 2

  def deck_y, do: card_center_y()

  def table_card_x, do: 0
  def table_card_y, do: card_center_y()

  def hand_card_x(index) do
    case index do
      i when i in [0, 3] -> -@card_width * 1.5
      i when i in [1, 4] -> -@card_width / 2
      i when i in [2, 5] -> @card_width / 2
    end
  end

  def hand_card_y(index) do
    case index do
      i when i in 0..2 -> -@card_height
      _ -> 0
    end
  end

  def hand_positions(player_count) do
    case player_count do
      1 -> [:bottom]
      2 -> [:bottom, :top]
      3 -> [:bottom, :left, :right]
      4 -> [:bottom, :left, :top, :right]
    end
  end

  def player_positions(player_id, players) do
    positions = hand_positions(length(players))
    player_index = Enum.find_index(players, &(&1.id == player_id))
    players = Golf.rotate(players, player_index)
    Enum.zip(positions, players)
  end

  def highlight_hand_card?(user_id, holder, playable_cards, index) do
    card = String.to_existing_atom("hand_#{index}")
    user_id == holder and card in playable_cards
  end
end
