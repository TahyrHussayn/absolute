defmodule Absolute.Counter do
  @moduledoc """
  Global counter managed by a GenServer, broadcasting updates via Phoenix.PubSub.
  """
  use GenServer

  @topic "global_counter"

  def start_link(default) when is_integer(default) do
    GenServer.start_link(__MODULE__, default, name: __MODULE__)
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def increment do
    GenServer.call(__MODULE__, :increment)
  end

  def decrement do
    GenServer.call(__MODULE__, :decrement)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(Absolute.PubSub, @topic)
  end

  # Server Callbacks

  @impl true
  def init(count) do
    {:ok, count}
  end

  @impl true
  def handle_call(:get, _from, count) do
    {:reply, count, count}
  end

  @impl true
  def handle_call(:increment, _from, count) do
    new_count = count + 1
    broadcast(new_count)
    {:reply, new_count, new_count}
  end

  @impl true
  def handle_call(:decrement, _from, count) do
    new_count = count - 1
    broadcast(new_count)
    {:reply, new_count, new_count}
  end

  defp broadcast(count) do
    Phoenix.PubSub.broadcast(Absolute.PubSub, @topic, {:counter_updated, count})
  end
end
