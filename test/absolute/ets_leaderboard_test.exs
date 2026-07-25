defmodule Absolute.EtsLeaderboardTest do
  use ExUnit.Case, async: false

  alias Absolute.EtsLeaderboard

  # Generate a unique player name for each test to avoid cross-test contamination.
  defp unique_player, do: "TestPlayer_#{System.unique_integer([:positive])}"

  describe "get_leaderboard/0" do
    test "returns a list" do
      result = EtsLeaderboard.get_leaderboard()
      assert is_list(result)
    end

    test "each entry is a two-element tuple of {binary, integer}" do
      result = EtsLeaderboard.get_leaderboard()

      Enum.each(result, fn entry ->
        assert match?({player, score} when is_binary(player) and is_integer(score), entry)
      end)
    end

    test "leaderboard is sorted descending by score" do
      result = EtsLeaderboard.get_leaderboard()
      scores = Enum.map(result, fn {_player, score} -> score end)
      assert scores == Enum.sort(scores, :desc)
    end
  end

  describe "add_score/2" do
    test "returns the new total score for the player" do
      player = unique_player()
      score = EtsLeaderboard.add_score(player, 100)
      assert score == 100
    end

    test "adds the player to the leaderboard" do
      player = unique_player()
      EtsLeaderboard.add_score(player, 50)

      leaderboard = EtsLeaderboard.get_leaderboard()
      players = Enum.map(leaderboard, fn {p, _score} -> p end)
      assert player in players
    end

    test "accumulates scores across multiple calls for the same player" do
      player = unique_player()
      EtsLeaderboard.add_score(player, 300)
      total = EtsLeaderboard.add_score(player, 200)
      assert total == 500
    end

    test "scores from different players are independent" do
      player_a = unique_player()
      player_b = unique_player()

      EtsLeaderboard.add_score(player_a, 100)
      EtsLeaderboard.add_score(player_b, 200)

      leaderboard = EtsLeaderboard.get_leaderboard()
      board_map = Map.new(leaderboard)

      assert board_map[player_a] == 100
      assert board_map[player_b] == 200
    end

    test "adding zero points keeps the score unchanged" do
      player = unique_player()
      EtsLeaderboard.add_score(player, 500)
      total = EtsLeaderboard.add_score(player, 0)
      assert total == 500
    end
  end
end
