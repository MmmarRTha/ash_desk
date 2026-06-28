defmodule AshDeskWeb.ChatComponents do
  use AshDeskWeb, :html

  import AshDeskWeb.Helpers

  @doc """
  Renders a chat message bubble with proper alignment, status indicators,
  timestamp, and sender name.
  """
  attr :message, :map, required: true
  attr :current_user, :map, required: true
  attr :online_users, :map, default: %{}
  attr :on_retry, :string, default: nil

  def message_bubble(assigns) do
    ~H"""
    <div class={[
      "chat",
      message_same_user?(@message, @current_user) && "chat-end",
      !message_same_user?(@message, @current_user) && "chat-start"
    ]}>
      <div class="mb-1">
        <span class="text-xs font-bold">
          {message_sender_name(@message, @current_user)}
        </span>
        <time class="text-xs opacity-50">{relative_time(@message.created_at)}</time>
      </div>
      <div class={[
        "chat-bubble max-w-[80%] rounded-xl",
        message_same_user?(@message, @current_user) && "chat-bubble-primary text-primary-content",
        !message_same_user?(@message, @current_user) && "chat-bubble-customer",
        Map.get(@message, :status) == :sending && "opacity-60",
        Map.get(@message, :status) == :failed && "border-2 border-error"
      ]}>
        <p class="whitespace-pre-wrap break-words">{@message.body}</p>
        <div class="flex items-center justify-end gap-1 mt-1">
          <time class="text-[10px] opacity-70">
            {formatted_time(@message.created_at)}
          </time>
          <span
            :if={Map.get(@message, :status) == :sending}
            class="loading loading-spinner loading-xs"
          />
          <span :if={Map.get(@message, :status) == :sent} class="text-[10px] opacity-50">✓</span>
          <span :if={Map.get(@message, :status) == :failed} class="text-[10px] text-error">✗</span>
        </div>
      </div>
      <div :if={Map.get(@message, :status) == :failed and @on_retry} class="chat-footer mt-1">
        <button
          phx-click={@on_retry}
          phx-value-message-id={@message.id}
          phx-value-body={@message.body}
          class="text-xs text-error hover:underline"
        >
          Failed — tap to retry
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Conversation card for sidebar or list views.
  """
  attr :conversation, :map, required: true
  attr :active, :boolean, default: false
  attr :current_user, :map, required: true
  attr :navigate, :string, required: true
  attr :last_message_preview, :string, default: nil
  attr :unread, :boolean, default: false

  def conversation_card(assigns) do
    ~H"""
    <div class={[
      "card transition-colors cursor-pointer mb-2 border",
      @active && "bg-primary/5 border-primary/30",
      !@active && "bg-base-200 hover:bg-base-300 border-base-300 hover:border-primary/30"
    ]}>
      <.link navigate={@navigate} class="block p-3">
        <div class="flex items-center gap-3">
          <div class="relative">
            <div class="avatar placeholder">
              <div class={[
                "rounded-full w-10",
                @active && "bg-primary text-primary-content",
                !@active && "bg-base-300 text-base-content"
              ]}>
                <span class="text-sm font-bold">
                  {conversation_initial(@conversation)}
                </span>
              </div>
            </div>
            <span
              :if={@unread}
              class="absolute -top-0.5 -right-0.5 size-3 bg-success rounded-full ring-2 ring-base-100"
            />
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex justify-between items-center gap-2">
              <span class="font-medium text-sm truncate">
                {@conversation.subject || "No subject"}
              </span>
              <.status_badge status={@conversation.status} />
            </div>
            <p :if={@last_message_preview} class="text-xs opacity-50 truncate mt-0.5">
              {@last_message_preview}
            </p>
            <div class="text-[11px] opacity-40 mt-0.5">
              {relative_time(@conversation.updated_at || @conversation.created_at)}
            </div>
          </div>
        </div>
      </.link>
    </div>
    """
  end

  @doc """
  Online presence indicators — avatar stack with green dot.
  """
  attr :users, :map, required: true
  attr :max_display, :integer, default: 3

  def presence_indicators(assigns) do
    ~H"""
    <div :if={@users != %{}} class="flex items-center gap-2">
      <div class="flex gap-0.5">
        <div :for={{_user_id, user} <- Enum.take(@users, @max_display)}>
          <span class="text-sm">{presence_emoji(user)}</span>
        </div>
      </div>
      <span class="text-xs text-blue-500 font-medium">
        {presence_count_text(@users, @max_display)}
      </span>
    </div>
    """
  end

  @doc """
  Typing indicator — shows "X is typing..." with animated dots.
  """
  attr :users, :map, required: true

  def typing_indicator(assigns) do
    ~H"""
    <div
      :if={@users != %{}}
      class="text-xs mb-2 flex items-center gap-1.5 transition-all text-green-500 font-semibold"
    >
      <span class="loading loading-dots loading-xs" />
      {AshDeskWeb.TypingIndicator.typing_text(@users)}
    </div>
    """
  end

  @doc """
  Color-coded status badge for conversations.
  """
  attr :status, :atom, required: true

  def status_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm shrink-0",
      @status == :open && "badge-success",
      @status == :pending && "badge-warning",
      @status == :resolved && "badge-ghost"
    ]}>
      {@status}
    </span>
    """
  end

  @doc """
  Message input form with textarea and send button.
  """
  attr :form, :map, required: true
  attr :input_id, :integer, required: true
  attr :placeholder, :string, default: "Type your message..."

  def message_input(assigns) do
    ~H"""
    <.form
      for={@form}
      id="send-message-form"
      phx-submit="send_message"
    >
      <div class="relative">
        <.input
          id={"message-body-#{@input_id}"}
          field={@form[:body]}
          type="textarea"
          placeholder={@placeholder}
          class="w-full pr-12 p-2 py-3 bg-white rounded-md text-black"
          phx-hook="TypingIndicator"
          rows="1"
        />
        <button class="btn btn-primary btn-sm absolute rounded-full bottom-4 right-1.5">
          <.icon name="hero-paper-airplane" class="size-4" />
        </button>
      </div>
    </.form>
    """
  end

  @doc """
  Polished empty state with icon, title, optional message and action slot.
  """
  attr :icon, :string, default: "hero-chat-bubble-left-right"
  attr :title, :string, required: true
  attr :message, :string, default: nil
  slot :action

  def empty_state(assigns) do
    ~H"""
    <div class="text-center py-16">
      <.icon name={@icon} class="size-16 opacity-30 mx-auto mb-4" />
      <h3 class="text-lg font-medium opacity-70">{@title}</h3>
      <p :if={@message} class="text-sm opacity-50 mt-1">{@message}</p>
      <div :if={@action != []} class="mt-4">
        {render_slot(@action)}
      </div>
    </div>
    """
  end

  defp message_same_user?(message, current_user) do
    message.sender_id == current_user.id or
      (message.sender && message.sender.id == current_user.id) or
      (message.sender && message.sender.email == current_user.email)
  end

  defp message_sender_name(message, current_user) do
    cond do
      message_same_user?(message, current_user) ->
        "You"

      message.sender && message.sender.email ->
        message.sender.email

      message.sender_id ->
        "Support"

      true ->
        "Unknown"
    end
  end

  defp formatted_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%I:%M %p")
  end

  defp formatted_time(_), do: ""

  defp conversation_initial(conversation) do
    cond do
      conversation.subject && conversation.subject != "" ->
        String.upcase(String.first(conversation.subject))

      true ->
        "?"
    end
  end

  defp presence_emoji(user) do
    role =
      case user.metas do
        [meta | _] -> Map.get(meta, :role)
        _ -> nil
      end

    case role do
      "admin" -> "👩‍💻"
      "agent" -> "🤓"
      "customer" -> "😺"
      _ -> "🐱"
    end
  end

  defp presence_count_text(users, max) do
    count = map_size(users)

    cond do
      count == 0 -> ""
      count <= max -> "#{count} online"
      true -> "+#{count - max} online"
    end
  end
end
