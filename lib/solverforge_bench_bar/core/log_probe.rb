# frozen_string_literal: true

require "time"

module SolverForgeBenchBar
  module Core
    module LogProbe
      START_EVENT = /solver_start instance=(?<instance>\S+) solver=(?<solver>\S+) time_limit=(?<limit>\d+) watchdog=(?<watchdog>[0-9.]+)/
      END_EVENT = /solver_end instance=(?<instance>\S+) solver=(?<solver>\S+) time_limit=(?<limit>\d+)/
      TIMESTAMP = /\A(?<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{4}|[+-]\d{2}:\d{2}))/
      EXCEPTION_LINE = /\A(?:[A-Za-z_][\w.]*?(?:Error|Exception|Failure)|RuntimeError):\s+.+/

      module_function

      def inspect_run(run, config)
        log_path = run[:logPath].to_s
        repo_root = run[:repoRoot].to_s
        return unavailable("missing", "run log path is not recorded") if log_path.empty?
        return unavailable("unsafe", "run repository root is not recorded") if repo_root.empty?

        expanded_log = File.expand_path(log_path)
        expanded_root = File.expand_path(repo_root)
        return unavailable("unsafe", "run repository root is unavailable") unless File.directory?(expanded_root)
        unless path_within?(expanded_log, expanded_root)
          return unavailable("unsafe", "run log resolves outside its recorded repository root")
        end
        unless File.exist?(expanded_log)
          unless missing_path_within_root?(expanded_log, expanded_root)
            return unavailable("unsafe", "run log resolves outside its recorded repository root")
          end

          return unavailable("missing", "run log is missing")
        end

        safe_path = safe_log_path(expanded_log, expanded_root)
        unless safe_path
          return unavailable("missing", "run log is missing") unless File.exist?(expanded_log)

          return unavailable("unsafe", "run log resolves outside its recorded repository root")
        end
        return unavailable("missing", "run log is missing") unless File.file?(safe_path)
        return unavailable("unreadable", "run log is not readable") unless File.readable?(safe_path)

        tail, truncated = read_tail(safe_path, config.dig(:source, :logTailBytes).to_i)
        parse_tail(
          tail,
          file_mtime: File.mtime(safe_path).utc.iso8601,
          truncated: truncated
        )
      rescue SystemCallError => e
        unavailable("unreadable", Redaction.clean(e.message, limit: 200))
      end

      def safe_log_path(log_path, repo_root)
        expanded_log = File.expand_path(log_path)
        expanded_root = File.expand_path(repo_root)
        return nil unless File.directory?(expanded_root)
        return nil unless File.exist?(expanded_log)

        real_root = File.realpath(expanded_root)
        real_log = File.realpath(expanded_log)
        prefix = real_root.end_with?(File::SEPARATOR) ? real_root : "#{real_root}#{File::SEPARATOR}"
        return nil unless real_log.start_with?(prefix)

        real_log
      rescue SystemCallError
        nil
      end

      def path_within?(path, root)
        prefix = root.end_with?(File::SEPARATOR) ? root : "#{root}#{File::SEPARATOR}"
        path.start_with?(prefix)
      end

      def missing_path_within_root?(path, root)
        real_root = File.realpath(root)
        ancestor = path
        until File.exist?(ancestor) || File.symlink?(ancestor)
          parent = File.dirname(ancestor)
          return false if parent == ancestor

          ancestor = parent
        end

        real_ancestor = File.realpath(ancestor)
        real_ancestor == real_root || path_within?(real_ancestor, real_root)
      rescue SystemCallError
        false
      end

      def read_tail(path, limit)
        File.open(path, "rb") do |file|
          size = file.size
          offset = [size - limit, 0].max
          file.seek(offset)
          data = file.read(limit).to_s
          if offset.positive?
            newline = data.index("\n")
            data = newline ? data[(newline + 1)..] : ""
          end
          [data.encode("UTF-8", invalid: :replace, undef: :replace, replace: "�"), offset.positive?]
        end
      end

      def parse_tail(text, file_mtime:, truncated: false)
        current_work = nil
        last_event_at = nil
        terminal_event = nil
        terminal_at = nil
        terminal_message = nil
        after_failure = false

        text.each_line do |line|
          timestamp = timestamp_from_line(line)
          if (match = START_EVENT.match(line))
            current_work = {
              instance: match[:instance],
              solver: match[:solver],
              timeLimitSeconds: match[:limit].to_i,
              watchdogSeconds: match[:watchdog].to_f,
              startedAt: timestamp
            }
            last_event_at = latest_time(last_event_at, timestamp)
            terminal_event = nil
            terminal_at = nil
            terminal_message = nil
            after_failure = false
          elsif (match = END_EVENT.match(line))
            if current_work && work_matches?(current_work, match)
              current_work = nil
            end
            last_event_at = latest_time(last_event_at, timestamp)
          elsif line.include?("benchmark_completed")
            terminal_event = "completed"
            terminal_at = timestamp
            current_work = nil
            last_event_at = latest_time(last_event_at, timestamp)
            after_failure = false
          elsif line.include?("benchmark_failed")
            terminal_event = "failed"
            terminal_at = timestamp
            current_work = nil
            last_event_at = latest_time(last_event_at, timestamp)
            after_failure = true
          elsif after_failure && EXCEPTION_LINE.match?(line.strip)
            terminal_message = Redaction.clean(line, limit: 300)
          end
        end

        {
          status: "ok",
          fileMtime: normalize_time(file_mtime),
          lastEventAt: last_event_at || normalize_time(file_mtime),
          currentWork: current_work,
          terminalEvent: terminal_event,
          terminalAt: terminal_at,
          terminalMessage: terminal_message,
          tailTruncated: !!truncated,
          error: nil
        }
      end

      def timestamp_from_line(line)
        match = TIMESTAMP.match(line)
        match ? normalize_time(match[:timestamp]) : nil
      end

      def normalize_time(value)
        return nil if value.to_s.empty?

        Time.parse(value.to_s).utc.iso8601
      rescue ArgumentError
        nil
      end

      def latest_time(first, second)
        return first unless second
        return second unless first

        Time.parse(first) >= Time.parse(second) ? first : second
      end

      def work_matches?(work, match)
        work[:instance] == match[:instance] &&
          work[:solver] == match[:solver] &&
          work[:timeLimitSeconds] == match[:limit].to_i
      end

      def unavailable(status, message)
        {
          status: status,
          fileMtime: nil,
          lastEventAt: nil,
          currentWork: nil,
          terminalEvent: nil,
          terminalAt: nil,
          terminalMessage: nil,
          tailTruncated: false,
          error: message
        }
      end
    end
  end
end
