# frozen_string_literal: true

require "time"

module SolverForgeBenchBar
  module Core
    module Format
      module_function

      def chip_text(summary, status)
        active = summary[:activeCount].to_i
        attention = summary[:attentionRunCount].to_i
        return "SFB err" if status == "source-error" && !summary[:hasUsableData]

        pieces = if active.positive?
                   ["SFB #{active}"]
                 elsif attention.positive?
                   ["SFB"]
                 else
                   ["SFB idle"]
                 end
        pieces << "!#{attention}" if attention.positive?
        pieces.join(" ")
      end

      def tooltip_lines(snapshot, max_runs: 4, stale: false, now: Time.now)
        summary = snapshot[:summary] || {}
        source = snapshot[:source] || {}
        lines = ["SolverForge Bench#{stale ? ' (stale)' : ''}"]
        lines << "#{summary[:activeCount].to_i} active | #{summary[:attentionRunCount].to_i} attention | #{summary[:runningRows].to_i} rows"
        drift_count = summary[:warehouseDriftCount].to_i
        if drift_count.positive?
          noun = drift_count == 1 ? "row" : "rows"
          lines << "#{drift_count} stale warehouse #{noun} excluded from live monitor"
        end

        Array(snapshot[:runs]).sort_by { |run| run[:severityRank].to_i }.reverse.first(max_runs.to_i).each do |run|
          lines << run_tooltip_line(run, now: now)
        end

        if source[:status] == "error"
          lines << "Source: #{source[:error]}"
        end
        lines << "Left click: open | Middle click: refresh"
        lines
      end

      def run_tooltip_line(run, now: Time.now)
        current = run[:currentWork]
        detail = if current
                   current_work_detail(current, now)
                 elsif run.dig(:lastResult, :instance).to_s != ""
                   "last #{run.dig(:lastResult, :instance)} / #{run.dig(:lastResult, :solver)}"
                 else
                   "no persisted result"
                 end
        "#{run[:benchmarkLabel]}: #{run[:observedState]} | #{run[:resultCount]} rows | #{detail}"
      end

      def current_work_detail(current, now)
        pieces = ["#{current[:instance]} / #{current[:solver]} / #{current[:timeLimitSeconds]}s"]
        timing = []
        started_at = parse_time(current[:startedAt])
        timing << "elapsed #{duration([now - started_at, 0].max)}" if started_at
        watchdog = current[:watchdogSeconds].to_f
        timing << "watchdog #{duration(watchdog)}" if watchdog.positive?
        pieces << timing.join(" / ") unless timing.empty?
        pieces.join(" | ")
      end

      def duration(seconds)
        value = seconds.to_i
        return "#{value}s" if value < 60
        return "#{value / 60}m" if value < 3_600
        return "#{value / 3_600}h #{(value % 3_600) / 60}m" if value < 86_400

        "#{value / 86_400}d #{(value % 86_400) / 3_600}h"
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
