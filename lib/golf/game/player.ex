defmodule Golf.Game.Player do
  alias __MODULE__
  alias Golf.Game.Card

  defstruct [:id, :name, :held_card, hand: []]

  @type id :: binary
  @type hand_card :: {Card.t(), face_up? :: boolean}

  @type t :: %Player{
          id: id,
          name: String.t(),
          held_card: Card.t() | nil,
          hand: [hand_card]
        }

  @hand_size 6
  def hand_size(), do: @hand_size

  @spec new(id, binary) :: t
  def new(id, name) do
    %Player{id: id, name: name}
  end

  @spec update_name(t, binary) :: t
  def update_name(player, new_name) do
    %Player{player | name: new_name}
  end

  @spec give_cards(t, [Card.t()]) :: t
  def give_cards(player, cards) do
    hand = Enum.map(cards, fn card -> {card, false} end)
    %Player{player | hand: hand}
  end

  @spec flip_card(t, integer) :: t
  def flip_card(player, index) do
    hand = List.update_at(player.hand, index, fn {card, _face_up?} -> {card, true} end)
    %Player{player | hand: hand}
  end

  @spec hold_card(t, Card.t()) :: t
  def hold_card(player, card) do
    %Player{player | held_card: card}
  end

  @spec discard(t) :: {Card.t(), t}
  def discard(player) when is_binary(player.held_card) do
    card = player.held_card
    player = %Player{player | held_card: nil}
    {card, player}
  end

  @spec swap_card(t, integer) :: {Card.t(), t}
  def swap_card(%{held_card: held_card} = player, index) when is_binary(held_card) do
    {card, _face_up?} = Enum.at(player.hand, index)
    hand = List.replace_at(player.hand, index, {held_card, true})
    player = %Player{player | held_card: nil, hand: hand}
    {card, player}
  end

  defp golf_value({_card, false}), do: :none
  defp golf_value({card, _face_up?}), do: Card.golf_value(card)

  defp total_vals(vals, total) do
    case vals do
      # all match
      [a, a, a,
       a, a, a] when is_integer(a) ->
        -40

      # outer cols match
      [a, b, a,
       a, c, a] when is_integer(a) ->
        total_vals([b, c], total - 20)

      # left 2 cols match
      [a, a, b,
       a, a, c] when is_integer(a) ->
        total_vals([b, c], total - 10)

      # right 2 cols match
      [a, b, b,
       c, b, b] when is_integer(b) ->
        total_vals([a, c], total - 10)

      # left col match
      [a, b, c,
       a, d, e] when is_integer(a) ->
        total_vals([b, c, d, e], total)

      # middle col match
      [a, b, c,
       d, b, e] when is_integer(b) ->
        total_vals([a, c, d, e], total)

      # right col match
      [a, b, c,
       d, e, c] when is_integer(c) ->
        total_vals([a, b, d, e], total)

      # left col match, 2nd pass
      [a, b,
       a, c] when is_integer(a) ->
        total_vals([b, c], total)

      # right col match, 2nd pass
      [a, b,
       c, b] when is_integer(b) ->
        total_vals([a, c], total)

      [a,
       a] when is_integer(a) ->
        total

      _ ->
        Enum.reject(vals, & &1 == :none)
        |> Enum.sum()
        |> Kernel.+(total)
    end
  end

  @spec score(t) :: integer
  def score(player) do
    vals = Enum.map(player.hand, &golf_value/1)
    total_vals(vals, 0)
  end

  @spec cards_face_up(t) :: integer
  def cards_face_up(player) do
    Enum.count(player.hand, fn {_, face_up?} -> face_up? end)
  end

  @spec all_cards_face_up?(t) :: boolean
  def all_cards_face_up?(player) do
    cards_face_up(player) == @hand_size
  end

  @spec two_face_up?(t) :: boolean
  def two_face_up?(player) do
    cards_face_up(player) == 2
  end

  @spec one_face_down?(t) :: boolean
  def one_face_down?(player) do
    cards_face_up(player) == @hand_size - 1
  end
end
