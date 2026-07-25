defmodule Absolute.CrashWorkerTest do
  use ExUnit.Case, async: false

  alias Absolute.CrashWorker

  describe "get_status/0" do
    test "returns a map" do
      result = CrashWorker.get_status()
      assert is_map(result)
    end

    test "map has :status key" do
      result = CrashWorker.get_status()
      assert Map.has_key?(result, :status)
    end

    test "map has :restarts key" do
      result = CrashWorker.get_status()
      assert Map.has_key?(result, :restarts)
    end

    test "map has :uptime_seconds key" do
      result = CrashWorker.get_status()
      assert Map.has_key?(result, :uptime_seconds)
    end

    test "status is :alive" do
      result = CrashWorker.get_status()
      assert result.status == :alive
    end

    test "restarts is a non-negative integer" do
      result = CrashWorker.get_status()
      assert is_integer(result.restarts)
      assert result.restarts >= 0
    end

    test "uptime_seconds is a non-negative integer" do
      result = CrashWorker.get_status()
      assert is_integer(result.uptime_seconds)
      assert result.uptime_seconds >= 0
    end
  end

  describe "crash!/0" do
    test "terminates the current process, which is then restarted by the supervisor" do
      pid_before = Process.whereis(CrashWorker)
      assert is_pid(pid_before), "CrashWorker must be running before the test"

      ref = Process.monitor(pid_before)

      CrashWorker.crash!()

      # The monitored process should go down
      assert_receive {:DOWN, ^ref, :process, ^pid_before, _reason}, 2000

      # Allow the supervisor to restart it
      Process.sleep(200)

      pid_after = Process.whereis(CrashWorker)
      assert is_pid(pid_after), "CrashWorker should have been restarted by its supervisor"
      assert pid_after != pid_before, "Restarted pid should differ from the original"
    end

    test "worker is :alive again after restart" do
      pid_before = Process.whereis(CrashWorker)
      ref = Process.monitor(pid_before)

      CrashWorker.crash!()
      assert_receive {:DOWN, ^ref, :process, ^pid_before, _reason}, 2000

      Process.sleep(200)

      status = CrashWorker.get_status()
      assert status.status == :alive
    end

    test "restart count increases after a crash" do
      status_before = CrashWorker.get_status()
      restarts_before = status_before.restarts

      pid = Process.whereis(CrashWorker)
      ref = Process.monitor(pid)

      CrashWorker.crash!()
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 2000

      Process.sleep(200)

      status_after = CrashWorker.get_status()
      assert status_after.restarts > restarts_before
    end
  end
end
