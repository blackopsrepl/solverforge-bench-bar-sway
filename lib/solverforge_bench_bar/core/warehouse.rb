# frozen_string_literal: true

require "json"
require "time"
require "uri"

module SolverForgeBenchBar
  module Core
    module Warehouse
      class SourceError < StandardError; end

      NIGHTLY_COHORT_LIMIT = 100

      module_function

      def fetch(config)
        source = config.fetch(:source)
        sql = snapshot_query(
          active_limit: source[:activeRunLimit],
          recent_limit: source[:recentRunLimit],
          cohort_window_seconds: config.dig(:display, :cohortWindowSeconds)
        )
        started = monotonic_time
        result = Process.run_command(
          source[:psqlCommand],
          ["-X", "--quiet", "--no-align", "--tuples-only", "--set=ON_ERROR_STOP=1", "--command", sql],
          timeout: source[:commandTimeoutSeconds],
          env: psql_environment(config)
        )
        latency_ms = ((monotonic_time - started) * 1_000).round

        unless result.success?
          message = Redaction.clean(result.stderr)
          message = "read-only warehouse query failed" if message.empty?
          raise SourceError, message
        end

        parse_payload(result.stdout, latency_ms: latency_ms)
      rescue JSON::ParserError => e
        raise SourceError, "invalid warehouse JSON: #{e.message}"
      end

      def parse_payload(json, latency_ms: 0)
        raw = JSON.parse(json.to_s.strip, symbolize_names: true)
        {
          queriedAt: raw[:queried_at].to_s,
          latencyMs: latency_ms.to_i,
          activeRuns: Array(raw[:active_runs]).map { |run| normalize_active_run(run) },
          cohortRuns: Array(raw[:cohort_runs]).map { |run| normalize_recent_run(run) },
          recentRuns: Array(raw[:recent_runs]).map { |run| normalize_recent_run(run) }
        }
      end

      def psql_environment(config)
        source = config.fetch(:source)
        connection = connection_environment(Config.database_url(config))
        connection.merge(
          "PGCONNECT_TIMEOUT" => source[:connectTimeoutSeconds].to_s,
          "PGOPTIONS" => [
            "-c default_transaction_read_only=on",
            "-c statement_timeout=#{source[:statementTimeoutMilliseconds]}",
            "-c lock_timeout=#{source[:lockTimeoutMilliseconds]}",
            "-c application_name=solverforge_bench_bar"
          ].join(" ")
        )
      end

      def connection_environment(database_url)
        uri = URI.parse(database_url.to_s)
        hostname = uri.hostname
        unless %w[postgres postgresql].include?(uri.scheme) && hostname && uri.path.to_s != ""
          raise SourceError, "source.databaseUrl must be a PostgreSQL URL"
        end

        environment = {
          "PGHOST" => hostname,
          "PGDATABASE" => decode_component(uri.path.delete_prefix("/"))
        }
        environment["PGPORT"] = uri.port.to_s if uri.port
        environment["PGUSER"] = decode_component(uri.user) if uri.user
        environment["PGPASSWORD"] = decode_component(uri.password) if uri.password

        URI.decode_www_form(uri.query.to_s).each do |key, value|
          environment["PGSSLMODE"] = value if key == "sslmode"
        end
        environment
      rescue URI::InvalidURIError
        raise SourceError, "source.databaseUrl must be a valid PostgreSQL URL"
      end

      def decode_component(value)
        URI::DEFAULT_PARSER.unescape(value.to_s)
      end

      def normalize_active_run(run)
        data = symbolize(run)
        {
          id: data[:id].to_s,
          benchmarkName: data[:benchmark_name].to_s,
          benchmarkCategory: data[:benchmark_category].to_s,
          runKind: data[:run_kind].to_s,
          nightly: !!data[:nightly],
          warehouseStatus: data[:status].to_s,
          createdAt: data[:created_at].to_s,
          completedAt: data[:completed_at]&.to_s,
          resultCount: data[:result_count].to_i,
          solvers: Array(data[:solvers]).map(&:to_s),
          timeLimitsSeconds: Array(data[:time_limits_seconds]).map(&:to_i),
          repoRoot: data[:repo_root].to_s,
          logPath: data[:log_path].to_s,
          gitCommit: data[:git_commit]&.to_s,
          gitDirty: !!data[:git_dirty],
          metadata: symbolize(data[:metadata] || {}),
          lastResult: normalize_last_result(data),
          counters: normalize_counters(data),
          perSolver: symbolize(data[:per_solver] || {})
        }
      end

      def normalize_recent_run(run)
        data = symbolize(run)
        {
          id: data[:id].to_s,
          benchmarkName: data[:benchmark_name].to_s,
          benchmarkCategory: data[:benchmark_category].to_s,
          runKind: data[:run_kind].to_s,
          nightly: !!data[:nightly],
          warehouseStatus: data[:status].to_s,
          createdAt: data[:created_at].to_s,
          completedAt: data[:completed_at]&.to_s,
          resultCount: data[:result_count].to_i,
          solvers: Array(data[:solvers]).map(&:to_s),
          timeLimitsSeconds: Array(data[:time_limits_seconds]).map(&:to_i),
          failureError: Redaction.clean(data[:failure_error], limit: 300)
        }
      end

      def normalize_last_result(data)
        return nil if data[:last_result_at].to_s.empty?

        {
          rowIndex: data[:last_row_index].to_i,
          createdAt: data[:last_result_at].to_s,
          instance: data[:last_instance].to_s,
          solver: data[:last_solver].to_s,
          timeLimitSeconds: data[:last_time_limit_seconds].to_i,
          actualTimeSeconds: data[:last_actual_time_seconds].to_f,
          watchdogKilled: !!data[:last_watchdog_killed],
          runError: Redaction.clean(data[:last_run_error], limit: 240),
          hardFeasible: data[:last_hard_feasible]
        }
      end

      def normalize_counters(data)
        {
          runErrors: data[:run_error_count].to_i,
          watchdogKills: data[:watchdog_kill_count].to_i,
          infeasible: data[:infeasible_count].to_i,
          validationErrors: data[:validation_error_count].to_i,
          fairStartFailures: data[:fair_start_failure_count].to_i,
          wallTimeViolations: data[:wall_time_violation_count].to_i
        }
      end

      def snapshot_query(active_limit:, recent_limit:, cohort_window_seconds: 120)
        <<~SQL
          WITH active_base AS (
            SELECT *
            FROM benchmark_runs
            WHERE status = 'running'
            ORDER BY created_at DESC, id DESC
            LIMIT #{active_limit.to_i}
          ),
          active_rows AS (
            SELECT
              r.id::text AS id,
              r.benchmark_name,
              r.benchmark_category,
              r.run_kind::text AS run_kind,
              r.nightly,
              r.status::text AS status,
              r.created_at,
              r.completed_at,
              r.result_count,
              r.solvers,
              r.time_limits_seconds,
              r.repo_root,
              r.log_path,
              r.git_commit,
              r.git_dirty,
              r.metadata,
              last.row_index AS last_row_index,
              last.created_at AS last_result_at,
              last.instance AS last_instance,
              last.solver AS last_solver,
              last.time_limit_seconds AS last_time_limit_seconds,
              last.actual_time_seconds AS last_actual_time_seconds,
              last.watchdog_killed AS last_watchdog_killed,
              last.run_error AS last_run_error,
              last.hard_feasible AS last_hard_feasible,
              counts.run_error_count,
              counts.watchdog_kill_count,
              counts.infeasible_count,
              counts.validation_error_count,
              counts.fair_start_failure_count,
              counts.wall_time_violation_count,
              solver_stats.per_solver
            FROM active_base AS r
            LEFT JOIN LATERAL (
              SELECT
                row_index, created_at, instance, solver, time_limit_seconds,
                actual_time_seconds, watchdog_killed, run_error, hard_feasible
              FROM benchmark_results
              WHERE run_id = r.id
              ORDER BY row_index DESC
              LIMIT 1
            ) AS last ON true
            LEFT JOIN LATERAL (
              SELECT
                count(*) FILTER (WHERE NULLIF(run_error, '') IS NOT NULL)::integer AS run_error_count,
                count(*) FILTER (WHERE watchdog_killed)::integer AS watchdog_kill_count,
                count(*) FILTER (WHERE hard_feasible = false)::integer AS infeasible_count,
                count(*) FILTER (WHERE NULLIF(validation_error, '') IS NOT NULL)::integer AS validation_error_count,
                count(*) FILTER (WHERE NOT fair_start_valid)::integer AS fair_start_failure_count,
                count(*) FILTER (WHERE wall_time_over_limit)::integer AS wall_time_violation_count
              FROM benchmark_results
              WHERE run_id = r.id
            ) AS counts ON true
            LEFT JOIN LATERAL (
              SELECT COALESCE(jsonb_object_agg(grouped.solver, grouped.payload), '{}'::jsonb) AS per_solver
              FROM (
                SELECT
                  solver,
                  jsonb_build_object(
                    'rows', count(*),
                    'runErrors', count(*) FILTER (WHERE NULLIF(run_error, '') IS NOT NULL),
                    'watchdogKills', count(*) FILTER (WHERE watchdog_killed),
                    'validationErrors', count(*) FILTER (WHERE NULLIF(validation_error, '') IS NOT NULL)
                  ) AS payload
                FROM benchmark_results
                WHERE run_id = r.id
                GROUP BY solver
              ) AS grouped
            ) AS solver_stats ON true
          ),
          latest_nightly AS (
            SELECT max(created_at) AS anchor_created_at
            FROM benchmark_runs
            WHERE nightly
          ),
          cohort_rows AS (
            SELECT
              r.id::text AS id,
              r.benchmark_name,
              r.benchmark_category,
              r.run_kind::text AS run_kind,
              r.nightly,
              r.status::text AS status,
              r.created_at,
              r.completed_at,
              r.result_count,
              r.solvers,
              r.time_limits_seconds,
              r.failure_error
            FROM benchmark_runs AS r
            CROSS JOIN latest_nightly
            WHERE r.nightly
              AND r.status <> 'running'
              AND latest_nightly.anchor_created_at IS NOT NULL
              AND r.created_at >= latest_nightly.anchor_created_at - (#{cohort_window_seconds.to_i} * INTERVAL '1 second')
            ORDER BY r.created_at DESC, r.id DESC
            LIMIT #{NIGHTLY_COHORT_LIMIT}
          ),
          recent_rows AS (
            SELECT
              id::text AS id,
              benchmark_name,
              benchmark_category,
              run_kind::text AS run_kind,
              nightly,
              status::text AS status,
              created_at,
              completed_at,
              result_count,
              solvers,
              time_limits_seconds,
              failure_error
            FROM benchmark_runs
            WHERE status <> 'running'
            ORDER BY COALESCE(completed_at, created_at) DESC, id DESC
            LIMIT #{recent_limit.to_i}
          )
          SELECT jsonb_build_object(
            'queried_at', to_char(clock_timestamp() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
            'active_runs', COALESCE((SELECT jsonb_agg(to_jsonb(active_rows) ORDER BY created_at DESC) FROM active_rows), '[]'::jsonb),
            'cohort_runs', COALESCE((SELECT jsonb_agg(to_jsonb(cohort_rows) ORDER BY created_at DESC) FROM cohort_rows), '[]'::jsonb),
            'recent_runs', COALESCE((SELECT jsonb_agg(to_jsonb(recent_rows) ORDER BY COALESCE(completed_at, created_at) DESC) FROM recent_rows), '[]'::jsonb)
          );
        SQL
      end

      def symbolize(value)
        Config.symbolize(value)
      end

      def monotonic_time
        ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      end
    end
  end
end
