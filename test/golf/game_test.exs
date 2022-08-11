defmodule Golf.GameTest do
  use ExUnit.Case, async: true

  alias Golf.Game
  alias Game.{Event, Player}

  test "one player" do
    player_id = :erlang.unique_integer()
    player = Player.new(player_id, "bob")

    game_id = :erlang.unique_integer()
    game = Game.new(game_id, player)
    assert game.state == :not_started

    game = Game.start(game)
    assert game.state == :flip_two
    assert Game.playable_cards(game, player_id) ==
      [:hand_0, :hand_1, :hand_2, :hand_3, :hand_4, :hand_5]

    {:ok, game} = Game.handle_event(game, Event.new(:flip, player_id, %{index: 0}))
    assert game.state == :flip_two
    assert Game.playable_cards(game, player_id) ==
      [:hand_1, :hand_2, :hand_3, :hand_4, :hand_5]

    {:ok, game} = Game.handle_event(game, Event.new(:flip, player_id, %{index: 1}))
    assert game.state == :take
    assert Game.playable_cards(game, player_id) ==
      [:deck, :table]

    {:ok, game} = Game.handle_event(game, Event.new(:take_from_deck, player_id))
    assert game.state == :holding
    assert Game.playable_cards(game, player_id) ==
      [:held, :hand_0, :hand_1, :hand_2, :hand_3, :hand_4, :hand_5]

    {:ok, game} = Game.handle_event(game, Event.new(:discard, player_id))
    assert game.state == :flip
    assert Game.playable_cards(game, player_id) ==
      [:hand_2, :hand_3, :hand_4, :hand_5]

    {:ok, game} = Game.handle_event(game, Event.new(:flip, player_id, %{index: 2}))
    assert game.state == :take
    assert Game.playable_cards(game, player_id) ==
      [:deck, :table]

    {:ok, game} = Game.handle_event(game, Event.new(:take_from_table, player_id))
    assert game.state == :holding
    assert Game.playable_cards(game, player_id) ==
      [:held, :hand_0, :hand_1, :hand_2, :hand_3, :hand_4, :hand_5]

    {:ok, game} = Game.handle_event(game, Event.new(:swap, player_id, %{index: 3}))
    assert game.state == :take
    assert Game.playable_cards(game, player_id) ==
      [:deck, :table]

    {:ok, game} = Game.handle_event(game, Event.new(:take_from_deck, player_id))
    assert game.state == :holding
    assert Game.playable_cards(game, player_id) ==
      [:held, :hand_0, :hand_1, :hand_2, :hand_3, :hand_4, :hand_5]

    {:ok, game} = Game.handle_event(game, Event.new(:discard, player_id))
    assert game.state == :flip
    assert Game.playable_cards(game, player_id) ==
      [:hand_4, :hand_5]

    {:ok, game} = Game.handle_event(game, Event.new(:flip, player_id, %{index: 4}))
    assert game.state == :take
    assert Game.playable_cards(game, player_id) ==
      [:deck, :table]

    # {:ok, game} = Game.handle_event(game, Event.new(:take_from_table, player_id))
    # assert game.state == :holding
    # assert Game.playable_cards(game, player_id) ==
    #   [:held, :hand_0, :hand_1, :hand_2, :hand_3, :hand_4, :hand_5]

    # {:ok, game} = Game.handle_event(game, Event.new(:discard, player_id))

    IO.inspect(game)
  end
end
