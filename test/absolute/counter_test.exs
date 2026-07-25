defmodule Absolute.CounterTest do
  use ExUnit.Case, async: false

  alias Absolute.Counter

  describe "get/0" do
    test "returns an integer" do
      result = Counter.get()
      assert is_integer(result)
    end
  end

  describe "increment/0" do
    test "returns a number greater than the value before the call" do
      before = Counter.get()
      after_inc = Counter.increment()
      assert after_inc > before
    end

    test "each increment increases the counter by 1" do
      before = Counter.get()
      assert Counter.increment() == before + 1
    end
  end

  describe "decrement/0" do
    test "returns a number less than the value after a prior increment" do
      incremented = Counter.increment()
      decremented = Counter.decrement()
      assert decremented < incremented
    end

    test "decrement reverses a previous increment" do
      before = Counter.get()
      Counter.increment()
      after_dec = Counter.decrement()
      assert after_dec == before
    end
  end

  describe "subscribe/0 + PubSub broadcast" do
    test "subscribing then calling increment broadcasts {:counter_updated, n}" do
      Phoenix.PubSub.subscribe(Absolute.PubSub, "global_counter")
      Counter.increment()
      assert_receive {:counter_updated, _n}
    end

    test "broadcast value matches the new counter value" do
      Phoenix.PubSub.subscribe(Absolute.PubSub, "global_counter")
      expected = Counter.get() + 1
      Counter.increment()
      assert_receive {:counter_updated, ^expected}
    end

    test "Counter.subscribe/0 helper also subscribes correctly" do
      Counter.subscribe()
      Counter.increment()
      assert_receive {:counter_updated, _n}
    end
  end
end
