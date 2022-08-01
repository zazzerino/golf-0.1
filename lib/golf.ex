defmodule Golf do
  alias Golf.Game

  @spec gen_id() :: binary
  def gen_id() do
    min = String.to_integer("100000", 36)
    max = String.to_integer("ZZZZZZ", 36)

    max
    |> Kernel.-(min)
    |> :rand.uniform()
    |> Kernel.+(min)
    |> Integer.to_string(36)
  end

  @spec lookup_game(Game.id()) :: [{pid, any}]
  def lookup_game(game_id) do
    Registry.lookup(Golf.GameRegistry, game_id)
  end

  @spec gen_game_id() :: Game.id()
  def gen_game_id() do
    case lookup_game(id = gen_id()) do
      # name hasn't been registered, so we'll return it
      [] -> id
      # name has been registered, so we'll recurse and try again
      _ -> gen_game_id()
    end
  end

  @spec rotate(list, integer) :: list
  def rotate(list, n) do
    list
    |> Stream.cycle()
    |> Stream.drop(n)
    |> Stream.take(length(list))
    |> Enum.to_list()
  end
end
