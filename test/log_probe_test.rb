# frozen_string_literal: true

require_relative "test_helper"

class LogProbeTest < Minitest::Test
  LogProbe = SolverForgeBenchBar::Core::LogProbe

  def test_reads_current_work_from_bounded_log_tail
    Dir.mktmpdir do |dir|
      log = File.join(dir, "run.log")
      File.write(log, fixture("active_run.log"))
      config = temp_config(dir)
      run = active_run(repoRoot: dir, logPath: log)

      evidence = LogProbe.inspect_run(run, config)
      assert_equal "ok", evidence[:status]
      assert_equal "solverforge", evidence.dig(:currentWork, :solver)
      assert_equal 75.0, evidence.dig(:currentWork, :watchdogSeconds)
      assert_nil evidence[:terminalEvent]
    end
  end

  def test_detects_terminal_failure_without_persisting_raw_trace
    evidence = LogProbe.parse_tail(
      fixture("failed_run.log"),
      file_mtime: "2026-07-10T06:00:01Z"
    )

    assert_equal "failed", evidence[:terminalEvent]
    assert_equal "psycopg.OperationalError: the connection is closed", evidence[:terminalMessage]
    refute evidence.key?(:rawTail)
  end

  def test_rejects_log_symlink_outside_recorded_root
    Dir.mktmpdir do |dir|
      root = File.join(dir, "repo")
      FileUtils.mkdir_p(root)
      outside = File.join(dir, "secret.log")
      link = File.join(root, "run.log")
      File.write(outside, "secret")
      File.symlink(outside, link)

      evidence = LogProbe.inspect_run(active_run(repoRoot: root, logPath: link), temp_config(dir))
      assert_equal "unsafe", evidence[:status]
    end
  end

  def test_reports_nonexistent_in_root_log_as_missing
    Dir.mktmpdir do |dir|
      root = File.join(dir, "repo")
      FileUtils.mkdir_p(root)

      evidence = LogProbe.inspect_run(
        active_run(repoRoot: root, logPath: File.join(root, "not-created.log")),
        temp_config(dir)
      )

      assert_equal "missing", evidence[:status]
      assert_equal "run log is missing", evidence[:error]
    end
  end

  def test_reports_nonexistent_outside_root_log_as_unsafe
    Dir.mktmpdir do |dir|
      root = File.join(dir, "repo")
      FileUtils.mkdir_p(root)

      evidence = LogProbe.inspect_run(
        active_run(repoRoot: root, logPath: File.join(dir, "outside.log")),
        temp_config(dir)
      )

      assert_equal "unsafe", evidence[:status]
    end
  end

  def test_rejects_missing_log_beneath_symlinked_directory_outside_root
    Dir.mktmpdir do |dir|
      root = File.join(dir, "repo")
      outside = File.join(dir, "outside")
      FileUtils.mkdir_p([root, outside])
      File.symlink(outside, File.join(root, "logs"))

      evidence = LogProbe.inspect_run(
        active_run(repoRoot: root, logPath: File.join(root, "logs", "not-created.log")),
        temp_config(dir)
      )

      assert_equal "unsafe", evidence[:status]
    end
  end

  def test_new_solver_start_clears_terminal_evidence_from_reused_log
    evidence = LogProbe.parse_tail(
      <<~LOG,
        2026-07-18T01:00:00Z benchmark_failed
        RuntimeError: failed at /srv/private/old-run.log
        2026-07-18T01:00:02Z solver_start instance=fresh solver=solverforge time_limit=10 watchdog=15
      LOG
      file_mtime: "2026-07-18T01:00:02Z"
    )

    assert_equal "fresh", evidence.dig(:currentWork, :instance)
    assert_nil evidence[:terminalEvent]
    assert_nil evidence[:terminalAt]
    assert_nil evidence[:terminalMessage]
  end

  def test_tail_read_passes_the_configured_byte_limit_to_the_file
    fake_file = Object.new
    fake_file.define_singleton_method(:size) { 4_096 }
    fake_file.define_singleton_method(:seek) { |_offset| nil }
    fake_file.define_singleton_method(:read) do |length = nil|
      @read_length = length
      "x" * (length || 8_192)
    end
    fake_file.define_singleton_method(:read_length) { @read_length }

    File.stub(:open, ->(_path, _mode, &block) { block.call(fake_file) }) do
      tail, truncated = LogProbe.read_tail("unused.log", 4_096)

      assert_equal 4_096, fake_file.read_length
      assert_equal 4_096, tail.bytesize
      refute truncated
    end
  end
end
