defmodule AshDesk.Support.TypingServer do
  use GenServer

  def start_link(conversation_id) do
    GenServer.start_link(__MODULE__, conversation_id,
      name: {:via, Registry, {AshDesk.TypingRegistry, conversation_id}}
    )
  end

  def typing_start(conversation_id, user_id, email) do
    case DynamicSupervisor.start_child(AshDesk.TypingSupervisor, {__MODULE__, conversation_id}) do
      {:ok, pid} ->
        GenServer.cast(pid, {:typing_start, user_id, email})

      {:error, {:already_started, pid}} ->
        GenServer.cast(pid, {:typing_start, user_id, email})

      {:error, reason} ->
        require Logger
        Logger.error("Failed to start typing server: #{inspect(reason)}")
    end
  end

  def stopped_typing(conversation_id, user_id) do
    case Registry.lookup(AshDesk.TypingRegistry, conversation_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:stopped_typing, user_id})

      [] ->
        :ok
    end
  end

  @impl true
  def init(conversation_id) do
    {:ok, %{conversation_id: conversation_id, typing_users: %{}, timers: %{}}}
  end

  @impl true
  def handle_cast({:typing_start, user_id, email}, state) do
    if timer = state.timers[user_id] do
      Process.cancel_timer(timer)
    end

    Phoenix.PubSub.broadcast(
      AshDesk.PubSub,
      "conversation:typing:#{state.conversation_id}",
      {:typing, :start, user_id, email}
    )

    timer = Process.send_after(self(), {:clear_typing, user_id}, 3000)

    {:noreply,
     %{
       state
       | typing_users: Map.put(state.typing_users, user_id, %{email: email}),
         timers: Map.put(state.timers, user_id, timer)
     }}
  end

  @impl true
  def handle_cast({:stopped_typing, user_id}, state) do
    if timer = state.timers[user_id] do
      Process.cancel_timer(timer)
    end

    Phoenix.PubSub.broadcast(
      AshDesk.PubSub,
      "conversation:typing:#{state.conversation_id}",
      {:typing, :stop, user_id, ""}
    )

    {:noreply,
     %{
       state
       | typing_users: Map.delete(state.typing_users, user_id),
         timers: Map.delete(state.timers, user_id)
     }}
  end

  @impl true
  def handle_info({:clear_typing, user_id}, state) do
    Phoenix.PubSub.broadcast(
      AshDesk.PubSub,
      "conversation:typing:#{state.conversation_id}",
      {:typing, :stop, user_id, ""}
    )

    state = %{
      state
      | typing_users: Map.delete(state.typing_users, user_id),
        timers: Map.delete(state.timers, user_id)
    }

    state =
      if state.typing_users == %{} do
        Process.send_after(self(), :timeout, 30_000)
        state
      else
        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end
end
