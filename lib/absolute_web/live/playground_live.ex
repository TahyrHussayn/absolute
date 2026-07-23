defmodule AbsoluteWeb.PlaygroundLive do
  use AbsoluteWeb, :live_view

  alias Absolute.{Counter, CrashWorker, EtsLeaderboard, SessionWorker, TickerAgent}
  alias AbsoluteWeb.Presence

  @chat_topic "playground_chat"
  @presence_topic "playground_presence"

  @impl true
  def mount(_params, _session, socket) do
    user_id = "user_" <> Integer.to_string(:rand.uniform(9999))

    if connected?(socket) do
      Counter.subscribe()
      CrashWorker.subscribe()
      Phoenix.PubSub.subscribe(Absolute.PubSub, @chat_topic)
      Phoenix.PubSub.subscribe(Absolute.PubSub, @presence_topic)

      # Track presence
      {:ok, _} =
        Presence.track(self(), @presence_topic, user_id, %{
          online_at: inspect(System.system_time(:second)),
          user_id: user_id,
          node: to_string(Node.self())
        })

      :timer.send_interval(1000, self(), :tick_stats)
    end

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:counter, Counter.get())
      |> assign(:worker_status, CrashWorker.get_status())
      |> assign(:spawn_result, nil)
      |> assign(:spawning?, false)
      |> assign(:username, "BEAMer-" <> Integer.to_string(:rand.uniform(9999)))
      |> assign(:chat_form, to_form(%{"message" => ""}))
      |> assign(:stats, get_beam_stats())

      # Demo 6: ETS
      |> assign(:leaderboard, EtsLeaderboard.get_leaderboard())

      # Demo 7: DynamicSupervisor
      |> assign(:my_session_worker, nil)

      # Demo 8: Presence
      |> assign(:presences, list_presences())

      # Demo 9: Agent
      |> assign(:agent_counts, TickerAgent.get_counts())

      # Demo 10: Registry
      |> assign(:registered_processes, get_registry_processes())

      # Demo 11: Streams
      |> assign(:fib_result, nil)

      # Demo 12: Tail Call
      |> assign(:tco_result, nil)
      |> assign(:tco_running?, false)

      # Demo 13: Binary Pattern Matching
      |> assign(:raw_hex, "005001BB000000010000000050024000")
      |> assign(:parsed_packet, nil)

      # Demo 14: Telemetry
      |> assign(:telemetry_count, :persistent_term.get({:telemetry, :event_count}, 0))
      |> stream(:chat_messages, [
        %{
          id: "1",
          username: "System",
          text: "Welcome to the BEAM Playground!",
          time: current_time()
        }
      ])

    {:ok, socket}
  end

  # Event Handlers

  @impl true
  def handle_event("inc_counter", _params, socket) do
    Counter.increment()
    {:noreply, socket}
  end

  def handle_event("dec_counter", _params, socket) do
    Counter.decrement()
    {:noreply, socket}
  end

  def handle_event("crash_worker", _params, socket) do
    CrashWorker.crash!()
    {:noreply, socket}
  end

  def handle_event("spawn_processes", %{"count" => count_str}, socket) do
    count = String.to_integer(count_str)
    socket = assign(socket, :spawning?, true)
    pid = self()

    Task.start(fn ->
      start_mem = :erlang.memory(:total)
      start_time = System.monotonic_time(:millisecond)

      tasks =
        for i <- 1..count do
          Task.async(fn -> :math.sin(i) + :math.cos(i) end)
        end

      _results = Task.await_many(tasks, 30_000)

      end_time = System.monotonic_time(:millisecond)
      end_mem = :erlang.memory(:total)

      duration_ms = end_time - start_time
      mem_used_mb = Float.round((end_mem - start_mem) / (1024 * 1024), 2)

      send(pid, {:spawn_finished, count, duration_ms, mem_used_mb})
    end)

    {:noreply, socket}
  end

  def handle_event("send_message", %{"message" => msg}, socket) when byte_size(msg) > 0 do
    message_data = %{
      id: to_string(System.unique_integer([:positive])),
      username: socket.assigns.username,
      text: msg,
      time: current_time()
    }

    Phoenix.PubSub.broadcast(Absolute.PubSub, @chat_topic, {:new_message, message_data})
    {:noreply, assign(socket, :chat_form, to_form(%{"message" => ""}))}
  end

  def handle_event("send_message", _params, socket), do: {:noreply, socket}

  def handle_event("set_username", %{"username" => username}, socket) do
    name =
      if String.trim(username) == "", do: socket.assigns.username, else: String.trim(username)

    {:noreply, assign(socket, :username, name)}
  end

  # Demo 6: ETS Handlers
  def handle_event("add_ets_score", %{"player" => p, "score" => s}, socket)
      when byte_size(p) > 0 do
    case Integer.parse(s) do
      {points, _} -> EtsLeaderboard.add_score(p, points)
      :error -> EtsLeaderboard.add_score(p, 100)
    end

    {:noreply, assign(socket, :leaderboard, EtsLeaderboard.get_leaderboard())}
  end

  def handle_event("crash_ets_manager", _params, socket) do
    EtsLeaderboard.crash!()
    {:noreply, socket}
  end

  # Demo 7: DynamicSupervisor Handlers
  def handle_event("start_my_session", _params, socket) do
    sid = socket.assigns.user_id

    case DynamicSupervisor.start_child(Absolute.SessionSupervisor, {SessionWorker, sid}) do
      {:ok, _pid} ->
        {:noreply, assign(socket, :my_session_worker, SessionWorker.get_state(sid))}

      {:error, {:already_started, _pid}} ->
        {:noreply, assign(socket, :my_session_worker, SessionWorker.get_state(sid))}
    end
  end

  def handle_event("inc_session_click", _params, socket) do
    sid = socket.assigns.user_id
    SessionWorker.increment_clicks(sid)
    {:noreply, assign(socket, :my_session_worker, SessionWorker.get_state(sid))}
  end

  def handle_event("crash_my_session", _params, socket) do
    sid = socket.assigns.user_id
    SessionWorker.crash_session(sid)
    {:noreply, assign(socket, :my_session_worker, nil)}
  end

  # Demo 9: Agent Handlers
  def handle_event("inc_agent", %{"color" => color}, socket) do
    TickerAgent.increment(color)
    {:noreply, assign(socket, :agent_counts, TickerAgent.get_counts())}
  end

  # Demo 10: Registry Handlers
  def handle_event("register_process", %{"name" => name}, socket) when byte_size(name) > 0 do
    pid = self()

    Task.start(fn ->
      Registry.register(Absolute.SessionRegistry, name, :custom_value)
      send(pid, :registry_updated)
      # Keep process alive for 30s
      Process.sleep(30_000)
    end)

    {:noreply, socket}
  end

  # Demo 11: Stream Handler
  def handle_event("run_fib_stream", %{"count" => count_str}, socket) do
    count = String.to_integer(count_str)

    {microsec, fibs} =
      :timer.tc(fn ->
        Stream.unfold({0, 1}, fn {a, b} -> {a, {b, a + b}} end)
        |> Stream.take(count)
        |> Enum.to_list()
      end)

    res = %{count: count, time_ms: Float.round(microsec / 1000, 2), sample: Enum.take(fibs, 10)}
    {:noreply, assign(socket, :fib_result, res)}
  end

  # Demo 12: TCO Handler
  def handle_event("run_tco", %{"iterations" => iter_str}, socket) do
    iterations = String.to_integer(iter_str)
    pid = self()

    Task.start(fn ->
      start = System.monotonic_time(:millisecond)
      total = tail_recursive_sum(iterations, 0)
      duration = System.monotonic_time(:millisecond) - start
      send(pid, {:tco_done, iterations, total, duration})
    end)

    {:noreply, assign(socket, :tco_running?, true)}
  end

  # Demo 13: Binary Pattern Matching
  def handle_event("parse_binary", %{"hex" => hex_str}, socket) do
    clean_hex = String.replace(hex_str, ~r/[^0-9A-Fa-f]/, "")

    parsed =
      case Base.decode16(clean_hex, case: :mixed) do
        {:ok,
         <<src_port::16, dst_port::16, seq::32, ack::32, data_offset::4, _reserved::6, flags::6,
           window::16, _rest::binary>>} ->
          %{
            src_port: src_port,
            dst_port: dst_port,
            seq: seq,
            ack: ack,
            header_length: data_offset * 4,
            flags: flags,
            window_size: window,
            valid: true
          }

        _ ->
          %{valid: false}
      end

    {:noreply, assign(socket, :parsed_packet, parsed)}
  end

  # Info Callbacks

  @impl true
  def handle_info({:counter_updated, count}, socket) do
    {:noreply, assign(socket, :counter, count)}
  end

  @impl true
  def handle_info({:worker_started, _restarts}, socket) do
    {:noreply, assign(socket, :worker_status, CrashWorker.get_status())}
  end

  @impl true
  def handle_info({:worker_crashing, _restarts}, socket) do
    {:noreply,
     assign(socket, :worker_status, %{
       status: :crashing,
       restarts: socket.assigns.worker_status.restarts + 1,
       uptime_seconds: 0
     })}
  end

  @impl true
  def handle_info({:spawn_finished, count, duration_ms, mem_used_mb}, socket) do
    res = %{
      count: count,
      duration_ms: duration_ms,
      mem_used_mb: mem_used_mb,
      rate: trunc(count / (duration_ms / 1000 + 0.0001))
    }

    {:noreply, socket |> assign(:spawning?, false) |> assign(:spawn_result, res)}
  end

  @impl true
  def handle_info({:new_message, msg}, socket) do
    {:noreply, stream_insert(socket, :chat_messages, msg)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, :presences, list_presences())}
  end

  @impl true
  def handle_info(:registry_updated, socket) do
    {:noreply, assign(socket, :registered_processes, get_registry_processes())}
  end

  @impl true
  def handle_info({:tco_done, iterations, total, duration}, socket) do
    res = %{iterations: iterations, total: total, duration_ms: duration}
    {:noreply, socket |> assign(:tco_running?, false) |> assign(:tco_result, res)}
  end

  @impl true
  def handle_info(:tick_stats, socket) do
    sid = socket.assigns.user_id

    my_worker =
      try do
        SessionWorker.get_state(sid)
      catch
        _, _ -> nil
      end

    count = :persistent_term.get({:telemetry, :event_count}, 0) + 1
    :persistent_term.put({:telemetry, :event_count}, count)

    {:noreply,
     socket
     |> assign(:stats, get_beam_stats())
     |> assign(:worker_status, CrashWorker.get_status())
     |> assign(:leaderboard, EtsLeaderboard.get_leaderboard())
     |> assign(:my_session_worker, my_worker)
     |> assign(:agent_counts, TickerAgent.get_counts())
     |> assign(:registered_processes, get_registry_processes())
     |> assign(:telemetry_count, count)}
  end

  # Helpers

  defp tail_recursive_sum(0, acc), do: acc
  defp tail_recursive_sum(n, acc), do: tail_recursive_sum(n - 1, acc + n)

  defp list_presences do
    Presence.list(@presence_topic)
    |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
      Map.put(meta, :user_id, user_id)
    end)
  end

  defp get_registry_processes do
    Registry.select(Absolute.SessionRegistry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.map(fn {key, pid} -> %{name: inspect(key), pid: inspect(pid)} end)
  end

  defp get_beam_stats do
    memory = :erlang.memory()
    total_mb = Float.round(memory[:total] / (1024 * 1024), 2)
    processes_mb = Float.round(memory[:processes] / (1024 * 1024), 2)
    atom_mb = Float.round(memory[:atom] / (1024 * 1024), 2)
    binary_mb = Float.round(memory[:binary] / (1024 * 1024), 2)

    %{
      process_count: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      schedulers: :erlang.system_info(:schedulers_online),
      total_mb: total_mb,
      processes_mb: processes_mb,
      atom_mb: atom_mb,
      binary_mb: binary_mb,
      otp_release: :erlang.system_info(:otp_release) |> to_string()
    }
  end

  defp current_time do
    Calendar.strftime(Time.utc_now(), "%H:%M:%S")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-12">
        <!-- Hero Header -->
        <div class="text-center py-6 border-b border-base-300">
          <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-primary/10 text-primary text-xs font-semibold uppercase tracking-wider mb-3">
            <.icon name="hero-bolt" class="size-4" /> Comprehensive BEAM & Elixir Showcase
          </div>
          <h1 class="text-3xl font-extrabold tracking-tight sm:text-4xl">
            Complete BEAM Feature Playground
          </h1>
          <p class="mt-2 text-base text-base-content/70 max-w-2xl mx-auto">
            Interactive demonstrations of Erlang/OTP primitives, concurrency, fault-tolerance, lazy streams, pattern matching, and presence.
          </p>
        </div>

        <!-- Grid of Demos (14 Demos) -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
          <!-- Demo 1: Global PubSub Counter -->
          <div class="card bg-base-200 shadow-md hover:shadow-lg transition-all border border-base-300">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-xl flex items-center gap-2">
                  <.icon name="hero-arrow-path-rounded-square" class="size-5 text-primary" />
                  1. Real-Time PubSub Counter
                </h2>
                <span class="badge badge-primary badge-soft">Zero JS</span>
              </div>
              <p class="text-sm text-base-content/70">
                Open in multiple browser tabs! State updates across all clients instantaneously via Phoenix PubSub.
              </p>
              <div class="my-6 text-center">
                <span class="text-6xl font-black text-primary font-mono" id="counter-value">
                  {@counter}
                </span>
              </div>
              <div class="card-actions justify-center gap-4">
                <button
                  id="dec-counter-btn"
                  phx-click="dec_counter"
                  class="btn btn-outline btn-error btn-circle text-lg font-bold"
                >-</button>
                <button
                  id="inc-counter-btn"
                  phx-click="inc_counter"
                  class="btn btn-primary btn-circle text-lg font-bold"
                >+</button>
              </div>
            </div>
          </div>

          <!-- Demo 2: Process Spawner -->
          <div class="card bg-base-200 shadow-md hover:shadow-lg transition-all border border-base-300">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-xl flex items-center gap-2">
                  <.icon name="hero-cpu-chip" class="size-5 text-secondary" />
                  2. Mass Concurrency Spawner
                </h2>
                <span class="badge badge-secondary badge-soft">BEAM Processes</span>
              </div>
              <p class="text-sm text-base-content/70">
                Spawn tens of thousands of lightweight green threads (~2KB each) concurrently.
              </p>
              <div class="card-actions justify-center gap-2 my-4">
                <button
                  id="spawn-10k-btn"
                  phx-click="spawn_processes"
                  phx-value-count="10000"
                  disabled={@spawning?}
                  class="btn btn-secondary btn-sm"
                >Spawn 10k</button>
                <button
                  id="spawn-50k-btn"
                  phx-click="spawn_processes"
                  phx-value-count="50000"
                  disabled={@spawning?}
                  class="btn btn-secondary btn-sm"
                >Spawn 50k</button>
                <button
                  id="spawn-100k-btn"
                  phx-click="spawn_processes"
                  phx-value-count="100000"
                  disabled={@spawning?}
                  class="btn btn-secondary btn-outline btn-sm"
                >Spawn 100k</button>
              </div>

              <%= if @spawning? do %>
                <div class="flex items-center justify-center gap-2 py-3 text-secondary animate-pulse">
                  <.icon name="hero-arrow-path" class="size-5 motion-safe:animate-spin" />
                  <span class="font-medium text-sm">Executing concurrent processes...</span>
                </div>
              <% end %>

              <%= if @spawn_result do %>
                <div class="stats stats-vertical sm:stats-horizontal shadow bg-base-100 mt-2">
                  <div class="stat p-3">
                    <div class="stat-title text-xs">Spawned</div><div class="stat-value text-base text-secondary font-mono">
                      {@spawn_result.count}
                    </div>
                  </div>
                  <div class="stat p-3">
                    <div class="stat-title text-xs">Duration</div><div class="stat-value text-base text-secondary font-mono">
                      {@spawn_result.duration_ms} ms
                    </div>
                  </div>
                  <div class="stat p-3">
                    <div class="stat-title text-xs">Speed</div><div class="stat-value text-base text-secondary font-mono">
                      {@spawn_result.rate} /s
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Demo 3: Self-Healing Supervision -->
          <div class="card bg-base-200 shadow-md hover:shadow-lg transition-all border border-base-300">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-xl flex items-center gap-2">
                  <.icon name="hero-shield-check" class="size-5 text-accent" />
                  3. Self-Healing OTP Worker
                </h2>
                <span class="badge badge-accent badge-soft">"Let It Crash"</span>
              </div>
              <p class="text-sm text-base-content/70">
                Supervisors isolate worker failures and restart crashed components instantly.
              </p>

              <div class="bg-base-100 rounded-box p-4 my-4 space-y-2 font-mono text-sm border border-base-300">
                <div class="flex justify-between items-center">
                  <span class="text-base-content/70">Worker Status:</span>
                  <span class={[
                    "badge font-semibold",
                    @worker_status.status == :alive && "badge-success",
                    @worker_status.status == :crashing && "badge-error animate-pulse"
                  ]}>{@worker_status.status}</span>
                </div>
                <div class="flex justify-between items-center">
                  <span class="text-base-content/70">Total Restarts:</span>
                  <span class="font-bold text-accent font-mono">{@worker_status.restarts}</span>
                </div>
                <div class="flex justify-between items-center">
                  <span class="text-base-content/70">Uptime:</span>
                  <span class="font-mono">{@worker_status.uptime_seconds}s</span>
                </div>
              </div>

              <div class="card-actions justify-center">
                <button id="crash-worker-btn" phx-click="crash_worker" class="btn btn-error btn-block">
                  <.icon name="hero-bolt" class="size-5" /> Intentionally Crash Worker
                </button>
              </div>
            </div>
          </div>

          <!-- Demo 4: Live Multi-Tab Chat -->
          <div class="card bg-base-200 shadow-md hover:shadow-lg transition-all border border-base-300">
            <div class="card-body flex flex-col justify-between">
              <div>
                <div class="flex items-center justify-between">
                  <h2 class="card-title text-xl flex items-center gap-2">
                    <.icon name="hero-chat-bubble-left-right" class="size-5 text-info" />
                    4. Zero-JS Live Chat
                  </h2>
                  <span class="badge badge-info badge-soft">LiveView Stream</span>
                </div>
                <p class="text-sm text-base-content/70">
                  Real-time chat driven by Phoenix LiveView Streams and PubSub.
                </p>
              </div>

              <div class="mt-3">
                <form id="username-form" phx-change="set_username" class="mb-3">
                  <label class="input input-sm flex items-center gap-2 bg-base-100 border border-base-300">
                    <span class="text-xs text-base-content/60">Handle:</span>
                    <input type="text" name="username" value={@username} class="grow text-xs" />
                  </label>
                </form>

                <div
                  id="chat-messages"
                  phx-update="stream"
                  class="h-32 overflow-y-auto bg-base-100 rounded-box p-3 space-y-2 border border-base-300 text-sm mb-3"
                >
                  <div
                    :for={{id, msg} <- @streams.chat_messages}
                    id={id}
                    class="flex flex-col text-xs"
                  >
                    <div class="flex items-center gap-2">
                      <span class="font-bold text-info">{msg.username}</span>
                      <span class="text-[10px] text-base-content/50">{msg.time}</span>
                    </div>
                    <p class="text-base-content/90 mt-0.5">{msg.text}</p>
                  </div>
                </div>

                <.form
                  for={@chat_form}
                  id="chat-send-form"
                  phx-submit="send_message"
                  class="flex gap-2"
                >
                  <.input
                    field={@chat_form[:message]}
                    type="text"
                    placeholder="Type a message..."
                    class="input input-sm grow"
                  />
                  <button type="submit" class="btn btn-info btn-sm">Send</button>
                </.form>
              </div>
            </div>
          </div>

          <!-- Demo 6: ETS Leaderboard -->
          <div class="card bg-base-200 shadow-md hover:shadow-lg transition-all border border-base-300">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-xl flex items-center gap-2">
                  <.icon name="hero-table-cells" class="size-5 text-warning" />
                  6. ETS (In-Memory K/V Store)
                </h2>
                <span class="badge badge-warning badge-soft">Erlang Term Storage</span>
              </div>
              <p class="text-sm text-base-content/70">
                ETS resides in BEAM VM memory. Crash the GenServer manager —
                <strong>scores survive the crash!</strong>
              </p>

              <div class="bg-base-100 rounded-box p-3 border border-base-300 my-2 space-y-1 text-xs">
                <div
                  :for={{player, score} <- @leaderboard}
                  class="flex justify-between items-center py-1 border-b border-base-200 last:border-0"
                >
                  <span class="font-bold">{player}</span>
                  <span class="font-mono text-warning font-extrabold">{score} pts</span>
                </div>
              </div>

              <form phx-submit="add_ets_score" class="flex gap-2 my-1">
                <input type="text" name="player" placeholder="Player" class="input input-xs grow" />
                <input type="number" name="score" placeholder="Pts" class="input input-xs w-20" />
                <button type="submit" class="btn btn-warning btn-xs">+ Score</button>
              </form>

              <button phx-click="crash_ets_manager" class="btn btn-outline btn-error btn-xs mt-2">
                Crash ETS GenServer (Data Persists)
              </button>
            </div>
          </div>

          <!-- Demo 7: DynamicSupervisor -->
          <div class="card bg-base-200 shadow-md hover:shadow-lg transition-all border border-base-300">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-xl flex items-center gap-2">
                  <.icon name="hero-user-plus" class="size-5 text-primary" /> 7. DynamicSupervisor
                </h2>
                <span class="badge badge-primary badge-soft">Runtime Workers</span>
              </div>
              <p class="text-sm text-base-content/70">
                Spawn individual, isolated GenServer processes per user session dynamically at runtime.
              </p>

              <div class="bg-base-100 p-3 rounded-box border border-base-300 my-2 text-xs font-mono">
                <%= if @my_session_worker do %>
                  <div>Session Worker: <span class="text-success font-bold">Active</span></div>
                  <div>
                    Clicks: <span class="font-bold text-primary">{@my_session_worker.clicks}</span>
                  </div>
                  <div>Uptime: {@my_session_worker.uptime}s</div>
                <% else %>
                  <div class="text-base-content/60">No worker spawned for your tab yet.</div>
                <% end %>
              </div>

              <div class="flex gap-2">
                <button phx-click="start_my_session" class="btn btn-primary btn-xs grow">Spawn Session Process</button>
                <button
                  phx-click="inc_session_click"
                  disabled={!@my_session_worker}
                  class="btn btn-secondary btn-xs"
                >Click Worker</button>
                <button
                  phx-click="crash_my_session"
                  disabled={!@my_session_worker}
                  class="btn btn-error btn-xs"
                >Crash Worker</button>
              </div>
            </div>
          </div>

          <!-- Demo 8: Phoenix Presence (CRDT) -->
          <div class="card bg-base-200 shadow-md hover:shadow-lg transition-all border border-base-300">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-xl flex items-center gap-2">
                  <.icon name="hero-users" class="size-5 text-secondary" /> 8. Phoenix Presence (CRDT)
                </h2>
                <span class="badge badge-secondary badge-soft">{length(@presences)} Online</span>
              </div>
              <p class="text-sm text-base-content/70">
                Track active connections across the cluster in real-time with zero database using CRDTs.
              </p>

              <div class="bg-base-100 rounded-box p-3 border border-base-300 my-2 space-y-1.5 text-xs max-h-36 overflow-y-auto">
                <div :for={p <- @presences} class="flex items-center justify-between">
                  <div class="flex items-center gap-2">
                    <.icon name="hero-check-circle" class="size-3.5 text-success" />
                    <span class="font-mono font-semibold">{p.user_id}</span>
                  </div>
                  <span class="font-mono text-[10px] text-base-content/60">{p.node}</span>
                </div>
              </div>
            </div>
          </div>

          <!-- Demo 9: Agent Shared State -->
          <div class="card bg-base-200 shadow-md hover:shadow-lg transition-all border border-base-300">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-xl flex items-center gap-2">
                  <.icon name="hero-cube" class="size-5 text-accent" /> 9. Agent Shared State
                </h2>
                <span class="badge badge-accent badge-soft">3-Line State</span>
              </div>
              <p class="text-sm text-base-content/70">
                Elixir Agent provides a simple abstraction for shared state without mutexes or locks.
              </p>

              <div class="flex justify-around my-4 text-center">
                <div>
                  <div class="text-xs font-bold text-error">RED</div>
                  <div class="text-2xl font-black font-mono">{@agent_counts["red"]}</div>
                  <button
                    phx-click="inc_agent"
                    phx-value-color="red"
                    class="btn btn-error btn-xs mt-1"
                  >+1</button>
                </div>
                <div>
                  <div class="text-xs font-bold text-success">GREEN</div>
                  <div class="text-2xl font-black font-mono">{@agent_counts["green"]}</div>
                  <button
                    phx-click="inc_agent"
                    phx-value-color="green"
                    class="btn btn-success btn-xs mt-1"
                  >+1</button>
                </div>
                <div>
                  <div class="text-xs font-bold text-info">BLUE</div>
                  <div class="text-2xl font-black font-mono">{@agent_counts["blue"]}</div>
                  <button
                    phx-click="inc_agent"
                    phx-value-color="blue"
                    class="btn btn-info btn-xs mt-1"
                  >+1</button>
                </div>
              </div>
            </div>
          </div>

          <!-- Demo 10: Registry Process Lookup -->
          <div class="card bg-base-200 shadow-md hover:shadow-lg transition-all border border-base-300">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-xl flex items-center gap-2">
                  <.icon name="hero-magnifying-glass" class="size-5 text-info" /> 10. Process Registry
                </h2>
                <span class="badge badge-info badge-soft">{length(@registered_processes)} Registered</span>
              </div>
              <p class="text-sm text-base-content/70">
                Register and locate processes by custom keys across the system.
              </p>

              <form phx-submit="register_process" class="flex gap-2 my-2">
                <input
                  type="text"
                  name="name"
                  placeholder="Process Name (e.g. worker_a)"
                  class="input input-xs grow"
                />
                <button type="submit" class="btn btn-info btn-xs">Register Process</button>
              </form>

              <div class="bg-base-100 rounded-box p-2 border border-base-300 text-xs font-mono max-h-24 overflow-y-auto">
                <div
                  :for={proc <- @registered_processes}
                  class="flex justify-between text-[11px] py-0.5"
                >
                  <span class="font-bold text-info">{proc.name}</span>
                  <span class="text-base-content/60">{proc.pid}</span>
                </div>
              </div>
            </div>
          </div>

          <!-- Demo 11: Lazy Infinite Streams -->
          <div class="card bg-base-200 shadow-md hover:shadow-lg transition-all border border-base-300">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-xl flex items-center gap-2">
                  <.icon name="hero-arrow-trending-up" class="size-5 text-success" />
                  11. Lazy Infinite Streams
                </h2>
                <span class="badge badge-success badge-soft">Stream.unfold</span>
              </div>
              <p class="text-sm text-base-content/70">
                Compute infinite sequences on demand with constant memory usage.
              </p>

              <div class="flex gap-2 my-2">
                <button phx-click="run_fib_stream" phx-value-count="10" class="btn btn-success btn-xs">Fib 10</button>
                <button
                  phx-click="run_fib_stream"
                  phx-value-count="1000"
                  class="btn btn-success btn-xs"
                >Fib 1,000</button>
                <button
                  phx-click="run_fib_stream"
                  phx-value-count="100000"
                  class="btn btn-success btn-outline btn-xs"
                >Fib 100,000</button>
              </div>

              <%= if @fib_result do %>
                <div class="bg-base-100 p-2 rounded-box border border-base-300 text-xs font-mono">
                  <div>
                    Computed {@fib_result.count} numbers in <strong>{@fib_result.time_ms} ms</strong>
                  </div>
                  <div class="text-[10px] text-base-content/60 mt-1 truncate">
                    First 10: {inspect(@fib_result.sample)}
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Demo 12: Tail Call Optimization -->
          <div class="card bg-base-200 shadow-md hover:shadow-lg transition-all border border-base-300">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-xl flex items-center gap-2">
                  <.icon name="hero-arrow-path" class="size-5 text-primary" />
                  12. Tail Call Optimization
                </h2>
                <span class="badge badge-primary badge-soft">Zero Stack Growth</span>
              </div>
              <p class="text-sm text-base-content/70">
                BEAM transforms tail calls into jumps. Recurse 1,000,000 times without stack overflow!
              </p>

              <div class="card-actions justify-center my-2">
                <button
                  phx-click="run_tco"
                  phx-value-iterations="1000000"
                  disabled={@tco_running?}
                  class="btn btn-primary btn-sm"
                >
                  Run 1,000,000 Recursions
                </button>
              </div>

              <%= if @tco_result do %>
                <div class="bg-base-100 p-2 rounded-box border border-base-300 text-xs font-mono text-center">
                  Completed {@tco_result.iterations} recursive calls in
                  <strong>{@tco_result.duration_ms} ms</strong>
                  (Sum: {@tco_result.total})
                </div>
              <% end %>
            </div>
          </div>

          <!-- Demo 13: Binary Pattern Matching -->
          <div class="card bg-base-200 shadow-md hover:shadow-lg transition-all border border-base-300">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-xl flex items-center gap-2">
                  <.icon name="hero-code-bracket-square" class="size-5 text-secondary" />
                  13. Binary Pattern Matching
                </h2>
                <span class="badge badge-secondary badge-soft">Native Bit syntax</span>
              </div>
              <p class="text-sm text-base-content/70">
                Parse raw binary TCP headers directly using Elixir's native
                <code>&lt;&lt;src::16, dst::16, ...&gt;&gt;</code>
                pattern matching.
              </p>

              <form phx-submit="parse_binary" class="flex gap-2 my-2">
                <input
                  type="text"
                  name="hex"
                  value={@raw_hex}
                  class="input input-xs grow font-mono text-[11px]"
                />
                <button type="submit" class="btn btn-secondary btn-xs">Parse Hex</button>
              </form>

              <%= if @parsed_packet && @parsed_packet.valid do %>
                <div class="bg-base-100 p-2 rounded-box border border-base-300 text-xs font-mono grid grid-cols-2 gap-1">
                  <div>
                    Src Port: <span class="font-bold text-primary">{@parsed_packet.src_port}</span>
                  </div>
                  <div>
                    Dst Port: <span class="font-bold text-secondary">{@parsed_packet.dst_port}</span>
                  </div>
                  <div>Seq: {@parsed_packet.seq}</div>
                  <div>Ack: {@parsed_packet.ack}</div>
                  <div>Window: {@parsed_packet.window_size}</div>
                  <div>Header: {@parsed_packet.header_length}B</div>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Demo 14: Telemetry Pipeline -->
          <div class="card bg-base-200 shadow-md hover:shadow-lg transition-all border border-base-300">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <h2 class="card-title text-xl flex items-center gap-2">
                  <.icon name="hero-chart-pie" class="size-5 text-accent" /> 14. Telemetry Pipeline
                </h2>
                <span class="badge badge-accent badge-soft">:telemetry</span>
              </div>
              <p class="text-sm text-base-content/70">
                Built-in event-driven metrics pipeline powering Phoenix observability.
              </p>

              <div class="bg-base-100 p-4 rounded-box border border-base-300 text-center my-2">
                <div class="text-xs text-base-content/60">Total System Events Emitted</div>
                <div class="text-3xl font-black font-mono text-accent mt-1">{@telemetry_count}</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Demo 5: BEAM Introspection Dashboard -->
        <div class="card bg-base-200 shadow-md border border-base-300">
          <div class="card-body">
            <div class="flex items-center justify-between mb-4">
              <h2 class="card-title text-xl flex items-center gap-2">
                <.icon name="hero-chart-bar" class="size-5 text-warning" />
                5. Live BEAM Introspection Dashboard
              </h2>
              <span class="badge badge-warning badge-soft">Updated Live (1s)</span>
            </div>

            <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
              <div class="bg-base-100 p-4 rounded-box border border-base-300 text-center">
                <div class="text-xs text-base-content/60 font-medium">OTP Version</div>
                <div class="text-xl font-extrabold text-primary font-mono mt-1">
                  OTP {@stats.otp_release}
                </div>
              </div>
              <div class="bg-base-100 p-4 rounded-box border border-base-300 text-center">
                <div class="text-xs text-base-content/60 font-medium">Active Processes</div>
                <div class="text-xl font-extrabold text-secondary font-mono mt-1">
                  {@stats.process_count}
                  <span class="text-xs text-base-content/50 font-normal">/ {@stats.process_limit}</span>
                </div>
              </div>
              <div class="bg-base-100 p-4 rounded-box border border-base-300 text-center">
                <div class="text-xs text-base-content/60 font-medium">CPU Schedulers</div>
                <div class="text-xl font-extrabold text-accent font-mono mt-1">
                  {@stats.schedulers} Cores
                </div>
              </div>
              <div class="bg-base-100 p-4 rounded-box border border-base-300 text-center">
                <div class="text-xs text-base-content/60 font-medium">Total BEAM Memory</div>
                <div class="text-xl font-extrabold text-info font-mono mt-1">
                  {@stats.total_mb} MB
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
