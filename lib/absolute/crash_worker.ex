defmodule Absolute.CrashWorker do
  @moduledoc """
  A worker GenServer designed to showcase OTP Supervision resilience ("Let It Crash").
  Tracks restart metrics across supervisor restarts using PersistentTerm or Application env/ETS.
  """
  use GenServer

  @topic "crash_worker"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status, 1000)
  catch
    :exit, _ -> %{status: :crashing, restarts: get_restarts(), uptime_seconds: 0}
  end

  def crash! do
    GenServer.cast(__MODULE__, :crash!)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(Absolute.PubSub, @topic)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    restarts = get_restarts() + 1
    :persistent_term.put({__MODULE__, :restarts}, restarts)
    started_at = System.monotonic_time(:second)
    broadcast({:worker_started, restarts})
    {:ok, %{restarts: restarts, started_at: started_at}}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    now = System.monotonic_time(:second)
    uptime = now - state.started_at

    status_info = %{
      status: :alive,
      restarts: state.restarts,
      uptime_seconds: uptime
    }

    {:reply, status_info, state}
  end

  @impl true
  def handle_cast(:crash!, state) do
    broadcast({:worker_crashing, state.restarts})
    # Deliberate exit/crash
    exit(:intentional_crash)
  end

  defp get_restarts do
    :persistent_term.get({__MODULE__, :restarts}, 0)
  end

  defp broadcast(event) do
    Phoenix.PubSub.broadcast(Absolute.PubSub, @topic, event)
  end
end
