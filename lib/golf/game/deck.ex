defmodule Golf.Game.Deck do
  alias Golf.Game.Card

  @type t :: [Card.t()]

  @card_list for rank <- ~w(A 2 3 4 5 6 7 8 9 T J Q K),
                 suit <- ~w(C D H S),
                 do: rank <> suit

  @spec new(integer) :: t
  def new(1), do: @card_list
  def new(n), do: @card_list ++ new(n - 1)

  @spec new() :: t
  def new(), do: new(1)

  @type deal_error :: :empty_deck | :not_enough_cards

  @spec deal(t, integer) :: {:ok, [Card.t()], t} | {:error, deal_error}
  def deal([], _) do
    {:error, :empty_deck}
  end

  def deal(deck, n) when length(deck) < n do
    {:error, :not_enough_cards}
  end

  def deal(deck, n) do
    {cards, deck} = Enum.split(deck, n)
    {:ok, cards, deck}
  end

  @spec deal(t) :: {:ok, Card.t(), t} | {:error, deal_error}
  def deal(deck) do
    with {:ok, [card], deck} <- deal(deck, 1) do
      {:ok, card, deck}
    end
  end
end
