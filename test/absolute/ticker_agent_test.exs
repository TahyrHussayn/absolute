defmodule Absolute.TickerAgentTest do
  use ExUnit.Case, async: false

  alias Absolute.TickerAgent

  describe "get_counts/0" do
    test "returns a map" do
      result = TickerAgent.get_counts()
      assert is_map(result)
    end

    test "map contains the \"red\" key" do
      result = TickerAgent.get_counts()
      assert Map.has_key?(result, "red")
    end

    test "map contains the \"green\" key" do
      result = TickerAgent.get_counts()
      assert Map.has_key?(result, "green")
    end

    test "map contains the \"blue\" key" do
      result = TickerAgent.get_counts()
      assert Map.has_key?(result, "blue")
    end

    test "all counts are non-negative integers" do
      counts = TickerAgent.get_counts()

      Enum.each(counts, fn {_color, count} ->
        assert is_integer(count)
        assert count >= 0
      end)
    end
  end

  describe "increment/1" do
    test "incrementing \"red\" increases the red count by 1" do
      before = TickerAgent.get_counts()
      TickerAgent.increment("red")
      after_inc = TickerAgent.get_counts()

      assert after_inc["red"] == before["red"] + 1
    end

    test "incrementing \"green\" increases the green count by 1" do
      before = TickerAgent.get_counts()
      TickerAgent.increment("green")
      after_inc = TickerAgent.get_counts()

      assert after_inc["green"] == before["green"] + 1
    end

    test "incrementing \"blue\" increases the blue count by 1" do
      before = TickerAgent.get_counts()
      TickerAgent.increment("blue")
      after_inc = TickerAgent.get_counts()

      assert after_inc["blue"] == before["blue"] + 1
    end

    test "incrementing \"red\" does not affect \"green\" or \"blue\"" do
      before = TickerAgent.get_counts()
      TickerAgent.increment("red")
      after_inc = TickerAgent.get_counts()

      assert after_inc["green"] == before["green"]
      assert after_inc["blue"] == before["blue"]
    end

    test "incrementing \"green\" does not affect \"red\" or \"blue\"" do
      before = TickerAgent.get_counts()
      TickerAgent.increment("green")
      after_inc = TickerAgent.get_counts()

      assert after_inc["red"] == before["red"]
      assert after_inc["blue"] == before["blue"]
    end

    test "incrementing \"blue\" does not affect \"red\" or \"green\"" do
      before = TickerAgent.get_counts()
      TickerAgent.increment("blue")
      after_inc = TickerAgent.get_counts()

      assert after_inc["red"] == before["red"]
      assert after_inc["green"] == before["green"]
    end

    test "multiple increments accumulate correctly" do
      before = TickerAgent.get_counts()
      TickerAgent.increment("red")
      TickerAgent.increment("red")
      TickerAgent.increment("red")
      after_inc = TickerAgent.get_counts()

      assert after_inc["red"] == before["red"] + 3
    end
  end
end
