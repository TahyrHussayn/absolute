defmodule Absolute.TickerAgent do
  @moduledoc """
  Demonstrates Elixir Agents for ultra-simple shared mutable state.
  """
  use Agent

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{"red" => 0, "green" => 0, "blue" => 0} end, name: __MODULE__)
  end

  def get_counts do
    Agent.get(__MODULE__, & &1)
  end

  def increment(color) when color in ["red", "green", "blue"] do
    Agent.update(__MODULE__, &Map.update(&1, color, 1, fn count -> count + 1 end))
  end
end
