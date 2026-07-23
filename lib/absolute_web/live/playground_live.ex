defmodule AbsoluteWeb.PlaygroundLive do
  use AbsoluteWeb, :live_view

  alias Absolute.{Counter, CrashWorker}

  @chat_topic "playground_chat"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Counter.subscribe()
      CrashWorker.subscribe()
      Phoenix.PubSub.subscribe(Absolute.PubSub, @chat_topic)
      :timer.send_interval(1000, self(), :tick_stats)
    end

    socket =
      socket
      |> assign(:counter, Counter.get())
      |> assign(:worker_status, CrashWorker.get_status())
      |> assign(:spawn_result, nil)
      |> assign(:spawning?, false)
      |> assign(:username, "BEAMer-" <> Integer.to_string(:rand.uniform(9999)))
      |> assign(:chat_form, to_form(%{"message" => ""}))
      |> assign(:stats, get_beam_stats())
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
          Task.async(fn ->
            # Simulate micro work in lightweight BEAM process
            :math.sin(i) + :math.cos(i)
          end)
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

  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("set_username", %{"username" => username}, socket) do
    name =
      if String.trim(username) == "", do: socket.assigns.username, else: String.trim(username)

    {:noreply, assign(socket, :username, name)}
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
  def handle_info(:tick_stats, socket) do
    {:noreply,
     socket
     |> assign(:stats, get_beam_stats())
     |> assign(:worker_status, CrashWorker.get_status())}
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
            <.icon name="hero-bolt" class="size-4" /> BEAM Superpowers Showcase
          </div>
          <h1 class="text-3xl font-extrabold tracking-tight sm:text-4xl">
            Interactive BEAM Playground
          </h1>
          <p class="mt-2 text-base text-base-content/70 max-w-xl mx-auto">
            Experience real-time concurrency, fault tolerance, and live process management powered by Erlang/OTP & Phoenix LiveView.
          </p>
        </div>

        <!-- Grid of Demos -->
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
                Open this page in multiple browser tabs or windows! Clicking increment or decrement broadcasts state to all clients instantaneously via Phoenix PubSub.
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
                >
                  -
                </button>
                <button
                  id="inc-counter-btn"
                  phx-click="inc_counter"
                  class="btn btn-primary btn-circle text-lg font-bold"
                >
                  +
                </button>
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
                BEAM processes are lightweight green threads (~2KB each). Spawn tens of thousands of concurrent workers simultaneously without melting your CPU.
              </p>
              <div class="card-actions justify-center gap-2 my-4">
                <button
                  id="spawn-10k-btn"
                  phx-click="spawn_processes"
                  phx-value-count="10000"
                  disabled={@spawning?}
                  class="btn btn-secondary btn-sm"
                >
                  Spawn 10k
                </button>
                <button
                  id="spawn-50k-btn"
                  phx-click="spawn_processes"
                  phx-value-count="50000"
                  disabled={@spawning?}
                  class="btn btn-secondary btn-sm"
                >
                  Spawn 50k
                </button>
                <button
                  id="spawn-100k-btn"
                  phx-click="spawn_processes"
                  phx-value-count="100000"
                  disabled={@spawning?}
                  class="btn btn-secondary btn-outline btn-sm"
                >
                  Spawn 100k
                </button>
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
                    <div class="stat-title text-xs">Spawned</div>
                    <div class="stat-value text-base text-secondary font-mono">
                      {@spawn_result.count}
                    </div>
                  </div>
                  <div class="stat p-3">
                    <div class="stat-title text-xs">Duration</div>
                    <div class="stat-value text-base text-secondary font-mono">
                      {@spawn_result.duration_ms} ms
                    </div>
                  </div>
                  <div class="stat p-3">
                    <div class="stat-title text-xs">Speed</div>
                    <div class="stat-value text-base text-secondary font-mono">
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
                In Erlang/OTP, components crash safely without bringing down the app. Supervisors restart failed workers in microseconds.
              </p>

              <div class="bg-base-100 rounded-box p-4 my-4 space-y-2 font-mono text-sm border border-base-300">
                <div class="flex justify-between items-center">
                  <span class="text-base-content/70">Worker Status:</span>
                  <span class={[
                    "badge font-semibold",
                    @worker_status.status == :alive && "badge-success",
                    @worker_status.status == :crashing && "badge-error animate-pulse"
                  ]}>
                    {@worker_status.status}
                  </span>
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
                <button
                  id="crash-worker-btn"
                  phx-click="crash_worker"
                  class="btn btn-error btn-block"
                >
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
                  Real-time chat driven entirely by Phoenix LiveView Streams and PubSub.
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
                  class="h-40 overflow-y-auto bg-base-100 rounded-box p-3 space-y-2 border border-base-300 text-sm mb-3"
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
                  <button type="submit" class="btn btn-info btn-sm">
                    Send
                  </button>
                </.form>
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

            <div class="grid grid-cols-3 gap-4 mt-2">
              <div class="bg-base-100 p-3 rounded-box border border-base-300 flex justify-between items-center text-xs">
                <span class="text-base-content/70">Process Memory:</span>
                <span class="font-bold font-mono">{@stats.processes_mb} MB</span>
              </div>
              <div class="bg-base-100 p-3 rounded-box border border-base-300 flex justify-between items-center text-xs">
                <span class="text-base-content/70">Atom Table Memory:</span>
                <span class="font-bold font-mono">{@stats.atom_mb} MB</span>
              </div>
              <div class="bg-base-100 p-3 rounded-box border border-base-300 flex justify-between items-center text-xs">
                <span class="text-base-content/70">Binary Memory:</span>
                <span class="font-bold font-mono">{@stats.binary_mb} MB</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
