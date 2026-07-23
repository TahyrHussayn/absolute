defmodule AbsoluteWeb.ClusterLive do
  use AbsoluteWeb, :live_view

  @topic "cluster_events"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Absolute.PubSub, @topic)
      :timer.send_interval(2000, self(), :tick_cluster)
    end

    socket =
      socket
      |> assign(:self_node, Node.self())
      |> assign(:nodes, Node.list())
      |> assign(:ping_result, nil)
      |> stream(:cluster_messages, [])

    {:ok, socket}
  end

  @impl true
  def handle_event("ping_node", %{"node_name" => node_str}, socket) do
    target = String.to_atom(String.trim(node_str))

    res =
      case Node.ping(target) do
        :pong -> {:success, "Successfully pinged #{target} (pong)"}
        :pang -> {:error, "Failed to reach node #{target} (pang)"}
      end

    {:noreply, assign(socket, :ping_result, res)}
  end

  def handle_event("send_cross_node", %{"message" => msg}, socket) when byte_size(msg) > 0 do
    evt = %{
      id: to_string(System.unique_integer([:positive])),
      sender: to_string(Node.self()),
      text: msg,
      time: Time.truncate(Time.utc_now(), :second) |> Time.to_string()
    }

    Phoenix.PubSub.broadcast(Absolute.PubSub, @topic, {:cluster_msg, evt})
    {:noreply, socket}
  end

  def handle_event("send_cross_node", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info(:tick_cluster, socket) do
    {:noreply,
     socket
     |> assign(:self_node, Node.self())
     |> assign(:nodes, Node.list())}
  end

  @impl true
  def handle_info({:cluster_msg, evt}, socket) do
    {:noreply, stream_insert(socket, :cluster_messages, evt)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-8 py-4">
        <!-- Hero Header -->
        <div class="border-b border-base-300 pb-6">
          <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-accent/10 text-accent text-xs font-semibold uppercase tracking-wider mb-2">
            <.icon name="hero-globe-alt" class="size-4" /> Multi-Node Distributed BEAM Cluster
          </div>
          <h1 class="text-3xl font-extrabold tracking-tight sm:text-4xl">
            Distributed Node Mesh
          </h1>
          <p class="mt-2 text-base text-base-content/70">
            Erlang/OTP nodes connect natively over TCP. Messages pass transparently across server instances anywhere in the cloud.
          </p>
        </div>

        <!-- Node Status Overview -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="card bg-base-200 border border-base-300 shadow-sm">
            <div class="card-body">
              <div class="text-xs text-base-content/60 font-semibold uppercase tracking-wider">
                Current Node
              </div>
              <div class="text-lg font-mono font-bold text-primary mt-1 truncate">
                {@self_node}
              </div>
              <div class="text-xs text-success flex items-center gap-1 mt-2">
                <.icon name="hero-check-circle" class="size-4" /> Active BEAM Instance
              </div>
            </div>
          </div>

          <div class="card bg-base-200 border border-base-300 shadow-sm">
            <div class="card-body">
              <div class="text-xs text-base-content/60 font-semibold uppercase tracking-wider">
                Connected Cluster Peers
              </div>
              <div class="text-3xl font-extrabold font-mono text-secondary mt-1">
                {length(@nodes)}
              </div>
              <div class="text-xs text-base-content/50 mt-1">
                {if @nodes == [],
                  do: "Running single node (connect EC2s for mesh)",
                  else: "#{length(@nodes)} peer(s) connected"}
              </div>
            </div>
          </div>

          <div class="card bg-base-200 border border-base-300 shadow-sm">
            <div class="card-body">
              <div class="text-xs text-base-content/60 font-semibold uppercase tracking-wider">
                Cluster PubSub
              </div>
              <div class="text-lg font-mono font-bold text-accent mt-1">
                Distributed CRDT
              </div>
              <div class="text-xs text-base-content/50 mt-1">
                State syncs across all nodes automatically
              </div>
            </div>
          </div>
        </div>

        <!-- Connected Nodes List -->
        <div class="card bg-base-200 border border-base-300 shadow-sm">
          <div class="card-body">
            <h2 class="card-title text-lg flex items-center gap-2">
              <.icon name="hero-server-stack" class="size-5 text-primary" /> Connected Cluster Nodes
            </h2>

            <%= if @nodes == [] do %>
              <div class="alert alert-info alert-soft my-2 text-xs">
                <.icon name="hero-information-circle" class="size-4 shrink-0" />
                <span>Currently running in <strong>single-node mode</strong>. Deploy to multiple EC2 instances using our AWS Cluster guide to see live multi-machine node meshing!</span>
              </div>
            <% else %>
              <ul class="list bg-base-100 rounded-box border border-base-300 divide-y divide-base-300 my-2">
                <li :for={n <- @nodes} class="list-row flex items-center justify-between p-3">
                  <div class="flex items-center gap-2">
                    <.icon name="hero-server" class="size-4 text-success" />
                    <span class="font-mono text-sm font-bold">{n}</span>
                  </div>
                  <span class="badge badge-success badge-sm">Connected</span>
                </li>
              </ul>
            <% end %>
          </div>
        </div>

        <!-- Cross-Node Messaging Demo -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <!-- Manual Node Ping Tester -->
          <div class="card bg-base-200 border border-base-300 shadow-sm">
            <div class="card-body">
              <h2 class="card-title text-base flex items-center gap-2">
                <.icon name="hero-paper-airplane" class="size-4 text-secondary" />
                Ping Remote BEAM Node
              </h2>
              <p class="text-xs text-base-content/70">
                Enter a target node name (e.g. <code>absolute@10.0.1.15</code>) to attempt node discovery via EPMD / Erlang Distribution.
              </p>

              <form phx-submit="ping_node" class="flex gap-2 mt-2">
                <input
                  type="text"
                  name="node_name"
                  placeholder="node_name@host"
                  class="input input-sm grow font-mono text-xs"
                />
                <button type="submit" class="btn btn-secondary btn-sm">
                  Ping Node
                </button>
              </form>

              <%= if @ping_result do %>
                <div class={[
                  "alert text-xs mt-3",
                  elem(@ping_result, 0) == :success && "alert-success",
                  elem(@ping_result, 0) == :error && "alert-error"
                ]}>
                  {elem(@ping_result, 1)}
                </div>
              <% end %>
            </div>
          </div>

          <!-- Cross-Node PubSub Broadcast -->
          <div class="card bg-base-200 border border-base-300 shadow-sm">
            <div class="card-body">
              <h2 class="card-title text-base flex items-center gap-2">
                <.icon name="hero-chat-bubble-bottom-center-text" class="size-4 text-accent" />
                Cross-Node Broadcast
              </h2>
              <p class="text-xs text-base-content/70">
                Broadcast messages across all cluster nodes in real-time.
              </p>

              <form phx-submit="send_cross_node" class="flex gap-2 mt-2">
                <input
                  type="text"
                  name="message"
                  placeholder="Broadcast to all nodes..."
                  class="input input-sm grow text-xs"
                />
                <button type="submit" class="btn btn-accent btn-sm">
                  Broadcast
                </button>
              </form>

              <div
                id="cluster-messages"
                phx-update="stream"
                class="h-28 overflow-y-auto bg-base-100 rounded-box p-3 space-y-1.5 border border-base-300 text-xs mt-3"
              >
                <div
                  :for={{id, msg} <- @streams.cluster_messages}
                  id={id}
                  class="flex justify-between items-center bg-base-200 p-1.5 rounded"
                >
                  <span class="font-mono text-primary font-semibold">{msg.sender}:</span>
                  <span class="grow ml-2">{msg.text}</span>
                  <span class="text-[10px] text-base-content/50">{msg.time}</span>
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
