require "posix/spawn"
require "securerandom"

module CC
  module Analyzer
    class Engine
      attr_reader :name

      TIMEOUT = 15 * 60 # 15m

      def initialize(name, metadata, code_path, config_json, label)
        @name = name
        @metadata = metadata
        @code_path = code_path
        @config_json = config_json
        @label = label.to_s
      end

      def run(stdout_io, stderr_io = StringIO.new)
        timed_out = false
        pid, _, out, err = POSIX::Spawn.popen4(*docker_run_command)

        t_out = Thread.new do
          out.each_line("\0") do |chunk|
            stdout_io.write(chunk.chomp("\0"))
          end
        end

        t_err = Thread.new do
          err.each_line do |line|
            if stderr_io
              stderr_io.write(line)
            end
          end
        end

        begin
          status = nil
          Timeout::timeout(TIMEOUT) do
            pid, status = Process.waitpid2(pid)
          end
        rescue Timeout::Error
          run_command("docker kill #{container_name} || true")
          timed_out = true
        end

        Analyzer.statsd.increment("cli.engines.finished")

        if timed_out
          Analyzer.statsd.increment("cli.engines.result.error")
          Analyzer.statsd.increment("cli.engines.result.error.timeout")
          Analyzer.statsd.increment("cli.engines.names.#{name}.result.error")
          Analyzer.statsd.increment("cli.engines.names.#{name}.result.error.timeout")
          raise EngineTimeout, "engine #{name} ran past #{TIMEOUT} seconds and was killed"
        elsif status.success?
          Analyzer.statsd.increment("cli.engines.names.#{name}.result.success")
          Analyzer.statsd.increment("cli.engines.result.success")
        else
          Analyzer.statsd.increment("cli.engines.names.#{name}.result.error")
          Analyzer.statsd.increment("cli.engines.result.error")
          raise EngineFailure, "engine #{name} failed with status #{status.exitstatus} and stderr #{stderr_io.string.inspect}"
        end
      ensure
        t_out.join if t_out
        t_err.join if t_err
      end

      private

      def container_name
        @container_name ||= "cc-engines-#{name}-#{SecureRandom.uuid}"
      end

      def docker_run_command
        [
          "docker", "run",
          "--rm",
          "--cap-drop", "all",
          "--label", "com.codeclimate.label=#{@label}",
          "--name", container_name,
          "--memory", 512_000_000.to_s, # bytes
          "--memory-swap", "-1",
          "--net", "none",
          "--volume", "#{@code_path}:/code:ro",
          "--env-file", env_file,
          @metadata["image_name"],
          @metadata["command"], # String or Array
        ].flatten.compact
      end

      def env_file
        path = File.join("/tmp/cc", SecureRandom.uuid)
        File.write(path, "ENGINE_CONFIG=#{@config_json}")
        path
      end

      def run_command(command)
        spawn = POSIX::Spawn::Child.new(command)

        unless spawn.status.success?
          raise CommandFailure, "command '#{command}' failed with status #{spawn.status.exitstatus} and output #{spawn.err}"
        end
      end

      CommandFailure = Class.new(StandardError)
      EngineFailure = Class.new(StandardError)
      EngineTimeout = Class.new(StandardError)
    end
  end
end
