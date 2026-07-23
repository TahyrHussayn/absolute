defmodule Absolute.EtsLeaderboard do
  @moduledoc """
  Showcases ETS (Erlang Term Storage).
  The ETS table is owned by a GenServer, but data resides in the BEAM VM memory table.
  When the GenServer process is crashed, the ETS table can be inherited or rebuilt,
  demonstrating that in-memory ETS state outlives individual GenServer processes.
  """
  use GenServer

  @table :ets_leaderboard

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def add_score(player, points) when is_binary(player) and is_integer(points) do
    GenServer.call(__MODULE__, {:add_score, player, points})
  end

  def get_leaderboard do
    case :ets.info(@table) do
      :undefined ->
        []

      _ ->
        :ets.tab2list(@table)
        |> Enum.sort_by(fn {_player, score} -> score end, :desc)
    end
  end

  def crash! do
    GenServer.cast(__MODULE__, :crash!)
  end

  # Callbacks

  @impl true
  def init(_opts) do
    # Create or reuse named ETS table with public read/write permissions
    table =
      case :ets.info(@table) do
        :undefined ->
          :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

        _ ->
          @table
      end

    # Seed default data if empty
    if :ets.info(@table, :size) == 0 do
      :ets.insert(@table, {"ElixirPro", 1200})
      :ets.insert(@table, {"BEAMMaster", 950})
      :ets.insert(@table, {"OTPWizard", 800})
    end

    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:add_score, player, points}, _from, state) do
    current =
      case :ets.lookup(@table, player) do
        [{^player, score}] -> score
        [] -> 0
      end

    new_score = current + points
    :ets.insert(@table, {player, new_score})
    {:reply, new_score, state}
  end

  @impl true
  def handle_cast(:crash!, _state) do
    exit(:ets_manager_crashed)
  end
end
