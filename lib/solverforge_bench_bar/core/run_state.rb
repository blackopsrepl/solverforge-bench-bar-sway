# frozen_string_literal: true

require "time"

module SolverForgeBenchBar
  module Core
    module RunState
      BENCHMARK_LABELS = {
        "cvrp" => "CVRP",
        "employee-scheduling" => "Employee scheduling",
        "job-shop-scheduling" => "Job-shop scheduling"
      }.freeze

      SEVERITY_RANK = {
        "healthy" => 0,
        "info" => 0,
        "warning" => 1,
        "critical" => 2
      }.freeze

      module_function

      def normalize_active(run, evidence, config, now: Time.now.utc)
        observed_state = observed_state(run, evidence, config, now)
        matrix_width = run[:solvers].length * run[:timeLimitsSeconds].length
        result_count = run[:resultCount].to_i
        current_work = normalize_current_work(evidence[:currentWork])
        last_activity_at = latest_timestamp(
          evidence[:lastEventAt],
          run.dig(:lastResult, :createdAt),
          run[:createdAt]
        )
        counters = run[:counters] || empty_counters
        attention_count = counters.values.sum
        severity = severity_for(observed_state, counters, evidence)

        {
          id: run[:id],
          shortId: run[:id].to_s.split("-").first,
          benchmarkName: run[:benchmarkName],
          benchmarkLabel: benchmark_label(run[:benchmarkName]),
          benchmarkCategory: run[:benchmarkCategory],
          runKind: run[:runKind],
          nightly: run[:nightly],
          warehouseStatus: run[:warehouseStatus],
          observedState: observed_state,
          severity: severity,
          createdAt: normalize_timestamp(run[:createdAt]),
          completedAt: normalize_timestamp(run[:completedAt]),
          resultCount: result_count,
          solvers: run[:solvers],
          timeLimitsSeconds: run[:timeLimitsSeconds],
          matrixWidth: matrix_width,
          completedCases: matrix_width.positive? ? result_count / matrix_width : 0,
          trialInCase: matrix_width.positive? ? result_count % matrix_width : 0,
          currentCase: matrix_width.positive? ? (result_count / matrix_width) + 1 : nil,
          currentWork: current_work,
          lastResult: run[:lastResult],
          counters: counters,
          attentionCount: attention_count,
          perSolver: run[:perSolver],
          lastActivityAt: last_activity_at,
          activityAgeSeconds: age_seconds(last_activity_at, now),
          log: {
            status: evidence[:status],
            terminalEvent: evidence[:terminalEvent],
            terminalAt: evidence[:terminalAt],
            terminalMessage: evidence[:terminalMessage],
            error: evidence[:error]
          }
        }
      end

      def normalize_recent(run)
        status = run[:warehouseStatus].to_s
        {
          id: run[:id],
          shortId: run[:id].to_s.split("-").first,
          benchmarkName: run[:benchmarkName],
          benchmarkLabel: benchmark_label(run[:benchmarkName]),
          benchmarkCategory: run[:benchmarkCategory],
          runKind: run[:runKind],
          nightly: run[:nightly],
          warehouseStatus: status,
          observedState: status,
          severity: status == "failed" ? "critical" : "healthy",
          createdAt: normalize_timestamp(run[:createdAt]),
          completedAt: normalize_timestamp(run[:completedAt]),
          resultCount: run[:resultCount].to_i,
          solvers: run[:solvers],
          timeLimitsSeconds: run[:timeLimitsSeconds],
          failureError: run[:failureError].to_s
        }
      end

      def observed_state(run, evidence, config, now)
        return "terminal-drift" if evidence[:terminalEvent]

        unless evidence[:status] == "ok"
          warehouse_activity = parse_time(latest_timestamp(
            run.dig(:lastResult, :createdAt),
            run[:createdAt]
          ))
          return "unknown" unless fresh?(warehouse_activity, run, config, now)

          return "active"
        end

        current = evidence[:currentWork]
        if current && current[:startedAt]
          started = parse_time(current[:startedAt])
          watchdog = current[:watchdogSeconds].to_f
          grace = config.dig(:display, :stallGraceSeconds).to_i
          return "stalled" if started && now > started + watchdog + grace

          return "active"
        end

        last_activity = parse_time(latest_timestamp(
          evidence[:lastEventAt],
          run.dig(:lastResult, :createdAt),
          run[:createdAt]
        ))
        return "unknown" unless last_activity

        fresh?(last_activity, run, config, now) ? "active" : "stalled"
      end

      def fresh?(activity, run, config, now)
        activity && now <= activity + maximum_watchdog(run) + config.dig(:display, :stallGraceSeconds).to_i
      end

      def maximum_watchdog(run)
        maximum_limit = Array(run[:timeLimitsSeconds]).map(&:to_f).max.to_f
        multiplier = numeric_metadata(run, :watchdog_multiplier, 1.25)
        grace = numeric_metadata(run, :watchdog_grace_seconds, 5.0)
        [maximum_limit * multiplier, maximum_limit + grace, 1.0].max
      end

      def numeric_metadata(run, key, fallback)
        value = run.dig(:metadata, key)
        value.nil? ? fallback : value.to_f
      end

      def severity_for(observed_state, counters, evidence)
        return "info" if observed_state == "terminal-drift"
        return "warning" if %w[stalled unknown].include?(observed_state)
        return "critical" if counters[:fairStartFailures].to_i.positive?
        return "warning" if counters.values.any? { |value| value.to_i.positive? }

        "healthy"
      end

      def normalize_current_work(work)
        return nil unless work

        started_at = normalize_timestamp(work[:startedAt])
        watchdog = work[:watchdogSeconds].to_f
        deadline = parse_time(started_at)
        {
          instance: work[:instance].to_s,
          solver: work[:solver].to_s,
          timeLimitSeconds: work[:timeLimitSeconds].to_i,
          watchdogSeconds: watchdog,
          startedAt: started_at,
          deadlineAt: deadline ? (deadline + watchdog).utc.iso8601 : nil
        }
      end

      def empty_counters
        {
          runErrors: 0,
          watchdogKills: 0,
          infeasible: 0,
          validationErrors: 0,
          fairStartFailures: 0,
          wallTimeViolations: 0
        }
      end

      def benchmark_label(name)
        BENCHMARK_LABELS.fetch(name.to_s, name.to_s.tr("-", " ").split.map(&:capitalize).join(" "))
      end

      def normalize_timestamp(value)
        time = parse_time(value)
        time&.utc&.iso8601
      end

      def latest_timestamp(*values)
        times = values.filter_map { |value| parse_time(value) }
        times.max&.utc&.iso8601
      end

      def age_seconds(timestamp, now)
        time = parse_time(timestamp)
        time ? [now - time, 0].max.round : nil
      end

      def parse_time(value)
        return nil if value.to_s.strip.empty?

        Time.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
