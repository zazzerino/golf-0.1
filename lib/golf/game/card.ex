defmodule Golf.Game.Card do
  @type t :: binary

  @spec golf_value(t) :: 0..10
  def golf_value(card) do
    <<rank, _suit>> = card

    case rank do
      ?K -> 0
      ?A -> 1
      ?2 -> 2
      ?3 -> 3
      ?4 -> 4
      ?5 -> 5
      ?6 -> 6
      ?7 -> 7
      ?8 -> 8
      ?9 -> 9
      ?T -> 10
      ?J -> 10
      ?Q -> 10
    end
  end
end
