defmodule GolfWeb.GameComponents do
  use GolfWeb, :html

  @game_width 600
  def game_width, do: @game_width

  @game_height 600
  def game_height, do: @game_height

  @game_viewbox "#{-@game_width / 2}, #{-@game_height / 2}, #{@game_width}, #{@game_height}"
  def game_viewbox, do: @game_viewbox

  @card_width 60
  def card_width, do: @card_width

  @card_height 84
  def card_height, do: @card_height

  @card_scale "10%"
  def card_scale, do: @card_scale

  @card_back "2B"
  def card_back, do: @card_back

  attr :name, :string, required: true
  attr :class, :string, default: nil
  attr :x, :integer, default: 0
  attr :y, :integer, default: 0
  attr :rest, :global

  def card_image(assigns) do
    ~H"""
    <image
      class={["card", @class]}
      href={"/images/cards/#{@name}.svg"}
      x={@x - card_width() / 2}
      y={@y - card_height() / 2}
      width={card_width()}
      {@rest}
    />
    """
  end

  def deck_x(:init), do: 0
  def deck_x(_), do: -@card_width / 2

  def deck_class(playable?) do
    if playable? do
      "deck highlight"
    else
      "deck"
    end
  end

  attr :game_status, :atom, required: true
  attr :playable, :boolean, required: true

  def deck(assigns) do
    ~H"""
    <.card_image
      name={card_back()}
      class={deck_class(@playable)}
      x={deck_x(@game_status)}
      phx-value-playable={@playable}
      phx-click="deck_click"
    />
    """
  end

  def table_card_x, do: @card_width / 2

  def table_card_class(playable?) do
    if playable? do
      "table highlight"
    else
      "table"
    end
  end

  attr :name, :string, required: true
  attr :playable, :boolean, required: true

  def table_card_0(assigns) do
    ~H"""
    <.card_image
      :if={@name}
      class={table_card_class(@playable)}
      name={@name}
      x={table_card_x()}
      phx-value-playable={@playable}
      phx-click="table_click"
    />
    """
  end

  attr :name, :string, required: true

  def table_card_1(assigns) do
    ~H"""
    <.card_image :if={@name} name={@name} x={table_card_x()} />
    """
  end

  attr :first, :string, required: true
  attr :second, :string, required: true
  attr :playable, :boolean, required: true

  def table_cards(assigns) do
    ~H"""
    <g id="table-cards">
      <.table_card_1 name={@second} />
      <.table_card_0 name={@first} playable={@playable} />
    </g>
    """
  end

  def hand_card_x(index) do
    case index do
      i when i in [0, 3] -> -@card_width
      i when i in [1, 4] -> 0
      i when i in [2, 5] -> @card_width
    end
  end

  def hand_card_y(index) do
    case index do
      i when i in 0..2 -> -@card_height / 2
      _ -> @card_height / 2
    end
  end

  def hand_index_playable?(playable_cards, index) do
    card = String.to_existing_atom("hand_#{index}")
    card in playable_cards
  end

  def hand_card_class(player_id, user_player_id, playable_cards, index) do
    if player_id == user_player_id and hand_index_playable?(playable_cards, index) do
      "highlight"
    end
  end

  attr :cards, :list, required: true
  attr :position, :atom, required: true
  attr :player_id, :integer, required: true
  attr :user_player_id, :integer, required: true
  attr :playable_cards, :list, required: true

  def hand(assigns) do
    ~H"""
    <g class={"hand #{@position}"}>
      <%= for {card, index} <- Enum.with_index(@cards) do %>
        <.card_image
          class={hand_card_class(@player_id, @user_player_id, @playable_cards, index)}
          name={if card["face_up?"], do: card["name"], else: card_back()}
          x={hand_card_x(index)}
          y={hand_card_y(index)}
          phx-value-index={index}
          phx-value-player-id={@player_id}
          phx-value-user-player-id={@user_player_id}
          phx-value-face-up={card["face_up?"]}
          phx-click="hand_click"
        />
      <% end %>
    </g>
    """
  end

  def held_card_class(position, playable?) do
    if playable? do
      "held #{position} highlight"
    else
      "held #{position}"
    end
  end

  attr :name, :string, required: true
  attr :position, :atom, required: true
  attr :playable, :boolean, required: true

  def held_card(assigns) do
    ~H"""
    <.card_image
      class={held_card_class(@position, @playable)}
      name={@name}
      phx-value-playable={@playable}
      phx-click="held_click"
    />
    """
  end

  attr :name, :string, required: true
  attr :score, :integer, required: true
  attr :position, :atom, required: true

  def player_info(assigns) do
    ~H"""
    <g class={"player-info #{@position}"}>
      <rect x="-90" y="-25" width="180" height="50" />
      <text>
        <%= "#{@name}: #{@score}" %>
      </text>
    </g>
    """
  end

  attr :id, :any, required: true
  attr :username, :string, required: true
  attr :content, :string, required: true

  def chat_message(assigns) do
    ~H"""
    <div id={@id}>
      <span class="game-chat-message-username">
        <%= @username %>:
      </span>

      <span class="game-chat-message-content">
        <%= @content %>
      </span>
    </div>
    """
  end

  attr :messages, :list, required: true

  def game_chat(assigns) do
    ~H"""
    <div id="game-chat" class="block">
      <h4 class="title is-5">Game Chat</h4>
      <div id="game-chat-messages" phx-hook="GameChatMessages">
        <.chat_message
          :for={message <- @messages}
          id={"message-#{message.id}"}
          username={message.username}
          content={message.content}
        />
      </div>
      <div id="game-chat-form" class="form">
        <input
          id="game-chat-input"
          class="input"
          phx-hook="GameChatInput"
          placeholder="Type chat message here"
          required
        />
        <input
          id="game-chat-button"
          class="button is-primary"
          phx-hook="GameChatButton"
          type="submit"
          value="Submit"
        />
      </div>
    </div>
    """
  end

  attr :requests, :list, required: true
  attr :game_status, :atom, required: true
  attr :host, :boolean, required: true

  def join_requests_table(assigns) do
    ~H"""
    <div class="join-requests block">
      <h4 class="title is-5">Join Requests</h4>
      <%= if Enum.empty?(@requests) do %>
        <p>No pending join requests.</p>
      <% else %>
        <table :if={@game_status == :init} class="table">
          <thead>
            <tr>
              <th>User Id</th>
              <th>Username</th>
            </tr>
          </thead>
          <tbody>
            <%= for req <- @requests do %>
              <tr>
                <td><%= req.user_id %></td>
                <td><%= req.username %></td>
                <td :if={@host}>
                  <button
                    class="button is-primary"
                    phx-value-request-id={req.id}
                    phx-click="confirm_join"
                  >
                    Confirm
                  </button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    </div>
    """
  end
end

# def table_card_class(event, playable?) when is_struct(event) do
#   case {event.action, playable?} do
#     {:discard, true} ->
#       "table highlight slide-from-held-#{event.position}"

#     {:discard, _} ->
#       "table slide-from-held-#{event.position}"

#     # {:swap, true} ->
#     #   "table highlight slide-from-hand-#{event.hand_index}-#{event.position}"

#     # {:swap, _} ->
#     #   "table slide-from-hand-#{event.hand_index}-#{event.position}"

#     {_, true} ->
#       "table highlight"

#     _ ->
#       "table"
#   end
# end

# def table_card_class(_, _), do: "table"

# def deck_class(game_status, playable?) do
#   case {game_status, playable?} do
#     {:init, _} ->
#       "deck slide-from-top"

#     {_, true} ->
#       "deck highlight"

#     _ ->
#       "deck"
#   end
# end

# def held_card_class(position, event, playable?) when is_struct(event) do
#   case {event.action, playable?} do
#     {:take_from_deck, true} ->
#       "held #{position} highlight slide-from-deck"

#     {:take_from_deck, _} ->
#       "held #{position} slide-from-deck"

#     {:take_from_table, true} ->
#       "held #{position} highlight slide-from-table"

#     {:take_from_table, _} ->
#       "held #{position} slide-from-table"

#     {_, true} ->
#       "held #{position} highlight"

#     _ ->
#       "held #{position}"
#   end
# end

# def held_card_class(position, _, _), do: "held #{position}"
