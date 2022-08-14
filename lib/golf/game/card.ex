defmodule Golf.Game.Card do
  @type rank :: integer
  @type suit :: integer
  @type t :: binary

  @spec rank_value(rank) :: 0..10
  def rank_value(rank) when is_integer(rank) do
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
      r when r in [?T, ?J, ?Q] -> 10
    end
  end
end
