# frozen_string_literal: true

require_relative "solverforge_bench_bar/core/config"
require_relative "solverforge_bench_bar/core/process"
require_relative "solverforge_bench_bar/core/redaction"
require_relative "solverforge_bench_bar/core/warehouse"
require_relative "solverforge_bench_bar/core/log_probe"
require_relative "solverforge_bench_bar/core/run_state"
require_relative "solverforge_bench_bar/core/format"
require_relative "solverforge_bench_bar/runtime/state"
require_relative "solverforge_bench_bar/runtime/presenter"
require_relative "solverforge_bench_bar/runtime/daemon"
require_relative "solverforge_bench_bar/runtime/quickshell"
require_relative "solverforge_bench_bar/runtime/waybar"
require_relative "solverforge_bench_bar/cli"

module SolverForgeBenchBar
  VERSION = "0.1.0"
end

