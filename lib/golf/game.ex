defmodule Golf.Game do
  @moduledoc """
  # States

  * :not_started

  The host has created the game and is waiting for players to join.

  actions: []
  next state: :flip_two

  * :init_hands

  Each player flips over two cards. Players can act in any order.

  actions: [:flip]
  next state: :take

  * :take

  The current player must take a card from the deck or table.

  actions: [:take_from_deck, :take_from_table]
  next state: :holding

  * :holding

  The current player must return their held card to the table or swap
  it with a card in their hand.

  actions: [:discard, :swap]

  next state: :game_over if all players cards are face up after :swap
              :take and go to next player if :swap
	      :flip if :discard

  * :flip

  The current player must flip over a card in their hand.
  This state is only entered after a player returns their held card to the table.

  actions: [:flip]

  * :game_over

  All players cards have been flipped.
  The player with the lowest score wins.
  """

  alias __MODULE__
  alias __MODULE__.{Card, Deck, Event, Player}

  defstruct id: nil,
            state: :not_started,
            host_id: nil,
            players: [],
            current_player_index: 0,
            deck: [],
            table_cards: [],
            final_round?: false,
            events: []

  @deck_count 2

  @type id :: binary
  @type state :: :not_started | :flip_two | :take | :holding | :flip | :game_over

  @type t :: %Game{
          id: id,
          state: state,
          host_id: Player.id(),
          players: [Player.t()],
          current_player_index: integer,
          deck: Deck.t(),
          table_cards: [Card.t()],
          final_round?: boolean,
          events: [Event.t()]
        }

  @spec new(id, Player.t()) :: t
  def new(id, player) do
    deck = Deck.new(@deck_count) |> Enum.shuffle()

    %Game{
      id: id,
      host_id: player.id,
      players: [player],
      deck: deck
    }
  end

  @spec add_player(t, Player.t()) :: t
  def add_player(game, player) do
    %Game{game | players: game.players ++ [player]}
  end

  @spec remove_player(t, Player.id()) :: t
  def remove_player(game, player_id) when player_id == game.host_id do
    next_player = Enum.at(game.players, next_player_index(game))

    %Game{
      game
      | host_id: next_player.id,
        players: reject_matching_id(game.players, player_id)
    }
  end

  def remove_player(game, player_id) do
    %Game{game | players: reject_matching_id(game.players, player_id)}
  end

  @spec deal_table_card(t) :: t
  defp deal_table_card(game) do
    {:ok, card, deck} = Deck.deal(game.deck)
    table_cards = [card | game.table_cards]
    %Game{game | deck: deck, table_cards: table_cards}
  end

  defp deal_hands(game, player_ids) do
    Enum.reduce(player_ids, game, fn player_id, game ->
      {:ok, cards, deck} = Deck.deal(game.deck, Player.hand_size())
      players = update_matching_id(game.players, player_id, &Player.give_cards(&1, cards))
      %Game{game | deck: deck, players: players}
    end)
  end

  @spec player_ids(t) :: [Player.id()]
  def player_ids(game) do
    Enum.map(game.players, & &1.id)
  end

  @spec start(t) :: t
  def start(game) do
    game
    |> deal_hands(player_ids(game))
    |> deal_table_card()
    |> Map.put(:state, :flip_two)
  end

  @spec update_player_name(t, Player.id(), binary) :: t
  def update_player_name(game, player_id, name) do
    players =
      update_matching_id(
        game.players,
        player_id,
        &Player.update_name(&1, name)
      )

    %Game{game | players: players}
  end

  @spec no_players?(t) :: boolean
  def no_players?(game) do
    Enum.empty?(game.players)
  end

  @spec get_player(t, Player.id()) :: Player.t() | nil
  def get_player(game, player_id) do
    Enum.find(game.players, fn p -> p.id == player_id end)
  end

  @spec is_players_turn?(t, Player.id()) :: boolean
  def is_players_turn?(game, player_id) do
    player_index = Enum.find_index(game.players, fn p -> p.id == player_id end)
    player_index == game.current_player_index
  end

  @spec handle_event(t, any) :: {:ok, t} | {:error, binary}
  def handle_event(%{state: :flip_two} = game, %{action: :flip} = event) do
    %{player_id: player_id, data: %{index: index}} = event
    player = get_player(game, player_id)

    if Player.num_cards_face_up(player) < 2 do
      players = update_matching_id(game.players, player.id, &Player.flip_card(&1, index))
      all_ready? = Enum.all?(players, &Player.two_face_up?/1)
      state = if all_ready?, do: :take, else: :flip_two
      events = [event | game.events]
      game = %Game{game | state: state, players: players, events: events}
      {:ok, game}
    else
      {:error, "Player #{player_id} already flipped two"}
    end
  end

  def handle_event(%{state: :take} = game, %{action: :take_from_deck} = event) do
    {:ok, card, deck} = Deck.deal(game.deck)
    players = update_matching_id(game.players, event.player_id, &Player.hold_card(&1, card))
    events = [event | game.events]
    game = %Game{game | state: :holding, deck: deck, players: players, events: events}
    {:ok, game}
  end

  def handle_event(%{state: :take} = game, %{action: :take_from_table} = event) do
    [card | table_cards] = game.table_cards
    players = update_matching_id(game.players, event.player_id, &Player.hold_card(&1, card))
    events = [event | game.events]

    game = %Game{
      game
      | state: :holding,
        table_cards: table_cards,
        players: players,
        events: events
    }

    {:ok, game}
  end

  def handle_event(%{state: :holding} = game, %{action: :discard} = event) do
    player = get_player(game, event.player_id)
    {card, player} = Player.discard(player)
    table_cards = [card | game.table_cards]
    players = replace_matching_id(game.players, player)
    events = [event | game.events]

    {state, player_index} =
      if Player.one_face_down?(player) do
        {:take, next_player_index(game)}
      else
        {:flip, game.current_player_index}
      end

    game = %Game{
      game
      | state: state,
        players: players,
        table_cards: table_cards,
        current_player_index: player_index,
        events: events
    }

    {:ok, game}
  end

  def handle_event(%{state: :holding} = game, %{action: :swap} = event) do
    %{player_id: player_id, data: %{index: index}} = event
    player = get_player(game, player_id)
    {card, player} = Player.swap_card(player, index)
    table_cards = [card | game.table_cards]
    players = replace_matching_id(game.players, player)
    events = [event | game.events]

    all_face_up? = Enum.all?(players, &Player.all_cards_face_up?/1)
    state = if all_face_up?, do: :game_over, else: :take

    player_face_up? = Player.all_cards_face_up?(player)
    final_round? = if player_face_up?, do: true, else: game.final_round?

    game = %Game{
      game
      | state: state,
        players: players,
        table_cards: table_cards,
        current_player_index: next_player_index(game),
        final_round?: final_round?,
        events: events
    }

    {:ok, game}
  end

  def handle_event(%{state: :flip} = game, %{action: :flip} = event) do
    %{player_id: player_id, data: %{index: index}} = event

    player =
      get_player(game, player_id)
      |> Player.flip_card(index)

    players = replace_matching_id(game.players, player)

    all_face_up? = Enum.all?(players, &Player.all_cards_face_up?/1)
    state = if all_face_up?, do: :game_over, else: :take

    player_all_face_up? = Player.all_cards_face_up?(player)
    final_round? = if player_all_face_up?, do: true, else: game.final_round?

    game = %Game{
      game
      | state: state,
        players: players,
        current_player_index: next_player_index(game),
        final_round?: final_round?,
        events: [event | game.events]
    }

    {:ok, game}
  end

  @flip_cards [:hand_0, :hand_1, :hand_2, :hand_3, :hand_4, :hand_5]
  @take_cards [:deck, :table]
  @holding_cards [:held, :hand_0, :hand_1, :hand_2, :hand_3, :hand_4, :hand_5]

  defp playable_card_positions(state) do
    case state do
      s when s in [:flip_two, :flip] -> @flip_cards
      :take -> @take_cards
      :holding -> @holding_cards
      _ -> []
    end
  end

  defp playable_hand_cards(hand) do
    hand
    |> Enum.with_index()
    |> Enum.reject(fn {{_, face_up?}, _} -> face_up? end)
    |> Enum.map(fn {_, index} -> String.to_existing_atom("hand_#{index}") end)
  end

  def playable_cards(%{state: :flip_two} = game, player_id) do
    player = get_player(game, player_id)

    if Player.two_face_up?(player) do
      []
    else
      playable_hand_cards(player.hand)
    end
  end

  def playable_cards(%{state: :flip} = game, player_id) do
    if is_players_turn?(game, player_id) do
      player = get_player(game, player_id)
      playable_hand_cards(player.hand)
    else
      []
    end
  end

  def playable_cards(game, player_id) do
    if is_players_turn?(game, player_id) do
      playable_card_positions(game.state)
    else
      []
    end
  end

  defp next_player_index(game) do
    next_index = game.current_player_index + 1
    num_players = length(game.players)
    rem(next_index, num_players)
  end

  defp reject_matching_id(maps, id) do
    Enum.reject(maps, & &1.id == id)
  end

  defp update_matching_id(maps, id, fun) do
    Enum.map(maps, fn m -> if m.id == id, do: fun.(m), else: m end)
  end

  defp replace_matching_id(maps, %{id: id} = map) do
    Enum.map(maps, fn m -> if m.id == id, do: map, else: m end)
  end
end

# def handle_event(%{final_round?: true} = game, %{action: :flip} = event) do
#   %{player_id: player_id, data: %{hand_index: hand_index}} = event
#   events = [event | game.events]
#   players = Map.update!(game.players, event.player_id, &Player.flip_card(&1, hand_index))
#   next_player_id = next_item(game.player_order, player_id)
#   {state, final_round?} = check_game_over(player_id, players, game.final_round?)

#   game = %Game{
#     game
#     | state: state,
#       players: players,
#       next_player_id: next_player_id,
#       final_round?: final_round?,
#       events: events
#   }

#   {:ok, reset_timer(game)}
# end
