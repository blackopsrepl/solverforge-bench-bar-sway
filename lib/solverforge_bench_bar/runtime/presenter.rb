# frozen_string_literal: true

require "time"

module SolverForgeBenchBar
  module Runtime
    module Presenter
      SUITE_ORDER = {
        "cvrp" => 0,
        "employee-scheduling" => 1,
        "job-shop-scheduling" => 2
      }.freeze

      module_function

      def apply(snapshot, config, stale: false, now: Time.now.utc)
        runs = decorate_runs(Array(snapshot[:runs]))
        cohort_runs = Array(snapshot[:cohortRuns])
        recent_runs = Array(snapshot[:recentRuns])
        drift_runs = runs.select { |run| run[:observedState] == "terminal-drift" }
        operational_runs = runs.reject { |run| run[:observedState] == "terminal-drift" }
        active_runs = operational_runs.select { |run| run[:observedState] == "active" }
        attention_runs = operational_runs.select { |run| run[:severityRank].to_i.positive? }
        cohort = current_cohort(runs, cohort_runs, config)
        summary = build_summary(runs, operational_runs, drift_runs, recent_runs, active_runs, attention_runs, cohort)
        status = overall_status(snapshot[:source], operational_runs, summary, stale)
        monitor_runs = active_runs.sort_by { |run| run[:createdAt].to_s }.reverse +
          operational_runs.reject { |run| run[:observedState] == "active" }
            .sort_by { |run| [-run[:severityRank].to_i, run[:createdAt].to_s] }
        chip = {
          text: Core::Format.chip_text(summary, status),
          tooltipLines: Core::Format.tooltip_lines(
            snapshot.merge(runs: monitor_runs, summary: summary),
            max_runs: config.dig(:display, :maxTooltipRuns),
            stale: stale,
            now: now
          ),
          classes: chip_classes(status, summary)
        }

        snapshot.merge(
          status: status,
          runs: runs,
          summary: summary,
          view: {
            chip: chip,
            summary: summary,
            headlineRun: headline_run(operational_runs),
            currentCohort: cohort,
            activeRuns: active_runs,
            attentionRuns: attention_runs,
            warehouseDriftRuns: drift_runs,
            monitorRuns: monitor_runs,
            recentRuns: recent_runs,
            staleAfterSeconds: config.dig(:display, :staleAfterSeconds).to_i,
            source: snapshot[:source] || {}
          }
        )
      end

      def decorate_runs(runs)
        runs.map do |run|
          run.merge(severityRank: Core::RunState::SEVERITY_RANK.fetch(run[:severity].to_s, 0))
        end
      end

      def build_summary(runs, operational_runs, drift_runs, recent_runs, active_runs, attention_runs, cohort)
        {
          runningCandidateCount: runs.length,
          operationalCandidateCount: operational_runs.length,
          warehouseDriftCount: drift_runs.length,
          warehouseDriftRows: drift_runs.sum { |run| run[:resultCount].to_i },
          activeCount: active_runs.length,
          attentionRunCount: attention_runs.length,
          runningRows: operational_runs.sum { |run| run[:resultCount].to_i },
          issueResultCount: operational_runs.sum { |run| run[:attentionCount].to_i },
          recentFailureCount: recent_runs.count { |run| run[:warehouseStatus] == "failed" },
          cohortSuiteCount: cohort[:runs].length,
          cohortCompletedCount: cohort[:completedCount],
          cohortActiveCount: cohort[:activeCount],
          cohortFailedCount: cohort[:failedCount],
          hasUsableData: runs.any? || recent_runs.any?
        }
      end

      def current_cohort(runs, cohort_runs, config)
        candidates_by_id = (cohort_runs + runs).each_with_object({}) do |run, indexed|
          indexed[run[:id].to_s] = run if run[:nightly] && parse_time(run[:createdAt])
        end
        candidates = candidates_by_id.values
        return empty_cohort if candidates.empty?

        anchor_time = candidates.map { |run| parse_time(run[:createdAt]) }.max
        window = config.dig(:display, :cohortWindowSeconds).to_i
        cohort_runs = candidates.select do |run|
          (anchor_time - parse_time(run[:createdAt])).abs <= window
        end.sort_by { |run| SUITE_ORDER.fetch(run[:benchmarkName].to_s, 99) }

        {
          startedAt: anchor_time.utc.iso8601,
          runs: cohort_runs,
          activeCount: cohort_runs.count { |run| run[:observedState] == "active" },
          completedCount: cohort_runs.count { |run| run[:warehouseStatus] == "completed" },
          failedCount: cohort_runs.count do |run|
            run[:warehouseStatus] == "failed" ||
              (run[:observedState] == "terminal-drift" && run.dig(:log, :terminalEvent) == "failed")
          end,
          attentionCount: cohort_runs.count do |run|
            !%w[active completed].include?(run[:observedState])
          end
        }
      end

      def empty_cohort
        { startedAt: nil, runs: [], activeCount: 0, completedCount: 0, failedCount: 0, attentionCount: 0 }
      end

      def overall_status(source, runs, summary, stale)
        return "stale" if stale
        return "source-error" if source && source[:status] == "error"
        return "warning" if summary[:attentionRunCount].positive?
        return "active" if summary[:activeCount].positive?

        "idle"
      end

      def chip_classes(status, summary)
        classes = ["benchbar", status]
        classes << (summary[:activeCount].positive? ? "active" : "idle")
        classes << "has-attention" if summary[:attentionRunCount].positive?
        classes << "has-result-issues" if summary[:issueResultCount].positive?
        classes << "source-error" if status == "source-error"
        classes.uniq
      end

      def headline_run(runs)
        runs.max_by do |run|
          [run[:severityRank].to_i, run[:observedState] == "active" ? 1 : 0, parse_time(run[:createdAt])&.to_i.to_i]
        end
      end

      def parse_time(value)
        Time.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
