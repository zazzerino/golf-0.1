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
  def update_name(player, name) do
    %Player{player | name: name}
  end

  @spec give_cards(t, [Card.t()]) :: t
  def give_cards(player, cards) do
    hand = Enum.map(cards, fn card -> {card, false} end)
    %Player{player | hand: hand}
  end

  @spec flip_card(t, integer) :: t
  def flip_card(player, index) do
    hand = List.update_at(player.hand, index, fn {card, _} -> {card, true} end)
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
    {card, _} = Enum.at(player.hand, index)
    hand = List.replace_at(player.hand, index, {held_card, true})
    player = %Player{player | held_card: nil, hand: hand}
    {card, player}
  end

  def rank_totals(ranks, total) do
    case ranks do
      # all match
      [a, a, a,
       a, a, a] when is_integer(a) ->
        -40

      # outer cols match
      [a, b, a,
       a, c, a] when is_integer(a) ->
        rank_totals([b, c], total - 20)

      # left 2 cols match
      [a, a, b,
       a, a, c] when is_integer(a) ->
        rank_totals([b, c], total - 10)

      # right 2 cols match
      [a, b, b,
       c, b, b] when is_integer(b) ->
        rank_totals([a, c], total - 10)

      # left col match
      [a, b, c,
       a, d, e] when is_integer(a) ->
        rank_totals([b, c, d, e], total)

      # middle col match
      [a, b, c,
       d, b, e] when is_integer(b) ->
        rank_totals([a, c, d, e], total)

      # right col match
      [a, b, c,
       d, e, c] when is_integer(c) ->
        rank_totals([a, b, d, e], total)

      # left col match, 2nd pass
      [a, b,
       a, c] when is_integer(a) ->
        rank_totals([b, c], total)

      # right col match, 2nd pass
      [a, b,
       c, b] when is_integer(b) ->
        rank_totals([a, c], total)

      [a,
       a] when is_integer(a) ->
        total

      _ ->
        Enum.reject(ranks, & &1 == :none)
        |> Enum.map(&Card.rank_value/1)
        |> Enum.sum()
        |> Kernel.+(total)
    end
  end

  defp rank_or_none({<<rank, _>>, true}), do: rank
  defp rank_or_none(_), do: :none

  def score(player) do
    player.hand
    |> Enum.map(&rank_or_none/1)
    |> rank_totals(0)
  end

  @spec num_cards_face_up(t) :: integer
  def num_cards_face_up(player) do
    Enum.count(player.hand, fn {_, face_up?} -> face_up? end)
  end

  @spec all_cards_face_up?(t) :: boolean
  def all_cards_face_up?(player) do
    num_cards_face_up(player) == @hand_size
  end

  @spec min_two_face_up?(t) :: boolean
  def min_two_face_up?(player) do
    num_cards_face_up(player) >= 2
  end

  @spec one_face_down?(t) :: boolean
  def one_face_down?(player) do
    num_cards_face_up(player) == @hand_size - 1
  end
end
