defmodule Absolute.SessionWorkerTest do
  use ExUnit.Case, async: false

  alias Absolute.SessionWorker

  # Generates a unique charlist session_id for each invocation to prevent registry conflicts.
  defp unique_session_id do
    'test_session_' ++ to_charlist(System.unique_integer([:positive]))
  end

  # Resolves the pid for a running SessionWorker from the registry.
  defp worker_pid(session_id) do
    case Registry.lookup(Absolute.SessionRegistry, session_id) do
      [{pid, _value}] -> pid
      [] -> nil
    end
  end

  describe "get_state/1" do
    test "returns a map" do
      session_id = unique_session_id()
      start_supervised!({SessionWorker, session_id})

      result = SessionWorker.get_state(session_id)
      assert is_map(result)
    end

    test "initial clicks count is 0" do
      session_id = unique_session_id()
      start_supervised!({SessionWorker, session_id})

      state = SessionWorker.get_state(session_id)
      assert state.clicks == 0
    end

    test "state contains the session_id" do
      session_id = unique_session_id()
      start_supervised!({SessionWorker, session_id})

      state = SessionWorker.get_state(session_id)
      assert state.session_id == session_id
    end

    test "state contains an uptime key" do
      session_id = unique_session_id()
      start_supervised!({SessionWorker, session_id})

      state = SessionWorker.get_state(session_id)
      assert Map.has_key?(state, :uptime)
    end

    test "uptime is a non-negative integer" do
      session_id = unique_session_id()
      start_supervised!({SessionWorker, session_id})

      state = SessionWorker.get_state(session_id)
      assert is_integer(state.uptime)
      assert state.uptime >= 0
    end
  end

  describe "increment_clicks/1" do
    test "increases the clicks count by 1" do
      session_id = unique_session_id()
      start_supervised!({SessionWorker, session_id})

      assert SessionWorker.increment_clicks(session_id) == 1
    end

    test "returns the new click total after each call" do
      session_id = unique_session_id()
      start_supervised!({SessionWorker, session_id})

      assert SessionWorker.increment_clicks(session_id) == 1
      assert SessionWorker.increment_clicks(session_id) == 2
      assert SessionWorker.increment_clicks(session_id) == 3
    end

    test "click count is reflected in get_state after increments" do
      session_id = unique_session_id()
      start_supervised!({SessionWorker, session_id})

      SessionWorker.increment_clicks(session_id)
      SessionWorker.increment_clicks(session_id)

      state = SessionWorker.get_state(session_id)
      assert state.clicks == 2
    end
  end

  describe "crash_session/1" do
    test "terminates the worker process" do
      session_id = unique_session_id()
      start_supervised!({SessionWorker, session_id})

      pid = worker_pid(session_id)
      assert is_pid(pid), "Worker should be running before crash"

      ref = Process.monitor(pid)
      SessionWorker.crash_session(session_id)

      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 2000
    end

    test "process is no longer in the registry after crash" do
      session_id = unique_session_id()
      start_supervised!({SessionWorker, session_id})

      pid = worker_pid(session_id)
      ref = Process.monitor(pid)

      SessionWorker.crash_session(session_id)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 2000

      # :transient workers are not restarted on abnormal exits by the DynamicSupervisor
      # but since we used start_supervised! in tests (ExUnit supervisor), it simply stops.
      assert worker_pid(session_id) == nil
    end
  end
end
