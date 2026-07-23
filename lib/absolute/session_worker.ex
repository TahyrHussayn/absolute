defmodule Absolute.SessionWorker do
  @moduledoc """
  A worker GenServer dynamically spawned by DynamicSupervisor for individual user sessions.
  Demonstrates per-session isolated processes.
  """
  use GenServer, restart: :transient

  def start_link(session_id) do
    GenServer.start_link(__MODULE__, session_id, name: via_tuple(session_id))
  end

  def get_state(session_id) do
    GenServer.call(via_tuple(session_id), :get_state)
  end

  def increment_clicks(session_id) do
    GenServer.call(via_tuple(session_id), :inc)
  end

  def crash_session(session_id) do
    GenServer.cast(via_tuple(session_id), :crash!)
  end

  def via_tuple(session_id) do
    {:via, Registry, {Absolute.SessionRegistry, session_id}}
  end

  # Callbacks

  @impl true
  def init(session_id) do
    started_at = System.monotonic_time(:second)
    {:ok, %{session_id: session_id, clicks: 0, started_at: started_at}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    now = System.monotonic_time(:second)
    uptime = now - state.started_at
    {:reply, Map.put(state, :uptime, uptime), state}
  end

  @impl true
  def handle_call(:inc, _from, state) do
    new_state = %{state | clicks: state.clicks + 1}
    {:reply, new_state.clicks, new_state}
  end

  @impl true
  def handle_cast(:crash!, _state) do
    exit(:session_crashed)
  end
end
