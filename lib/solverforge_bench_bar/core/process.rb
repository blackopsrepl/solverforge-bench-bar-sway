# frozen_string_literal: true

require "open3"

module SolverForgeBenchBar
  module Core
    module Process
      Result = Struct.new(:status, :stdout, :stderr, :timed_out, keyword_init: true) do
        def success?
          !timed_out && status&.success?
        end
      end

      module_function

      def run_command(command, args = [], timeout: 10, env: {})
        stdout_text = +""
        stderr_text = +""
        status = nil
        timed_out = false

        Open3.popen3(env, command, *args.map(&:to_s), pgroup: true) do |stdin, stdout, stderr, wait_thread|
          stdin.close
          stdout_reader = Thread.new { stdout.read }
          stderr_reader = Thread.new { stderr.read }

          unless wait_thread.join(timeout.to_f)
            timed_out = true
            terminate_process_group(wait_thread.pid)
            wait_thread.join(1)
          end

          status = wait_thread.value unless wait_thread.alive?
          stdout_text = stdout_reader.value
          stderr_text = stderr_reader.value
        ensure
          stdout_reader&.kill if stdout_reader&.alive?
          stderr_reader&.kill if stderr_reader&.alive?
        end

        stderr_text = "command timed out after #{timeout}s" if timed_out && stderr_text.strip.empty?
        Result.new(status: status, stdout: stdout_text, stderr: stderr_text, timed_out: timed_out)
      rescue Errno::ENOENT => e
        Result.new(status: nil, stdout: "", stderr: e.message, timed_out: false)
      end

      def terminate_process_group(pid)
        ::Process.kill("TERM", -pid)
        sleep(0.1)
        ::Process.kill("KILL", -pid)
      rescue Errno::ESRCH
        nil
      end
    end
  end
end

