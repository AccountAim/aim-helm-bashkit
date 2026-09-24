# frozen_string_literal: true

require "json"

module AimHelmBashkit
  # A sandboxed bash interpreter with an in-memory filesystem. Shell state and
  # files persist across `execute` calls on the same instance.
  #
  # Calls on one instance serialize; `cancel` is safe from any thread.
  class Bash
    # `files` seeds text files: { "/workspace/input.txt" => "hello\n" }.
    def initialize(
      profile: nil, cwd: nil, env: nil, files: nil, username: nil, hostname: nil,
      timeout_seconds: nil, parser_timeout_seconds: nil, readonly_filesystem: nil,
      capture_final_env: nil, max_commands: nil, max_input_bytes: nil, max_output_bytes: nil
    )
      limits = {
        max_commands:, max_input_bytes:, max_output_bytes:,
        timeout_ms: timeout_seconds && (timeout_seconds * 1000).round,
        parser_timeout_ms: parser_timeout_seconds && (parser_timeout_seconds * 1000).round
      }.compact

      @config = JSON.generate({
        schema_version: 1, profile: profile&.to_s, cwd:, env:, files:, username:, hostname:,
        readonly_filesystem:, capture_final_env:, limits: limits.empty? ? nil : limits
      }.compact)
      @handle = create
    end

    def execute(script)
      result_out = FFI::MemoryPointer.new(:pointer)
      Native.call(:bashkit_execute, handle, Native.bytes(script), result_out) do |status, message|
        return ExecResult.failure(message) if Native::FAILED_RUN.include?(status)

        raise Error.new(message, code: status)
      end
      take_result(result_out.read_pointer)
    end

    def execute!(script)
      execute(script).tap { raise BashError, it unless it.success? }
    end

    # Aborts the running execution at its next command boundary. Sticky until
    # `clear_cancel`: later executions fail immediately.
    def cancel
      Native.bashkit_cancel(handle)
      nil
    end

    def clear_cancel
      Native.bashkit_clear_cancel(handle)
      nil
    end

    # Discards shell state and files, keeping the constructor configuration.
    def reset
      close
      @handle = create
      nil
    end

    def close
      @handle&.free
      @handle = nil
    end

    def read_file(path)
      buffer_out = FFI::MemoryPointer.new(:pointer)
      Native.call(:bashkit_read_file, handle, Native.bytes(path), buffer_out)
      Native.take_buffer(buffer_out.read_pointer)
    end

    # Parent directories must exist.
    def write_file(path, content)
      Native.call(:bashkit_write_file, handle, Native.bytes(path), Native.bytes(content))
      nil
    end

    def mkdir(path, recursive: false)
      Native.call(:bashkit_mkdir, handle, Native.bytes(path), recursive ? 1 : 0)
      nil
    end

    def remove(path, recursive: false)
      Native.call(:bashkit_remove, handle, Native.bytes(path), recursive ? 1 : 0)
      nil
    end

    private

    def handle
      @handle or raise Error, "bash is closed"
    end

    def create
      bash_out = FFI::MemoryPointer.new(:pointer)
      Native.call(:bashkit_create_json, Native.bytes(@config), bash_out)
      FFI::AutoPointer.new(bash_out.read_pointer, Native.method(:bashkit_free))
    end

    def take_result(pointer)
      flags = Native.bashkit_result_flags(pointer)
      final_env = Native.read(Native.bashkit_result_final_env_json(pointer))

      ExecResult.new(
        stdout: Native.read(Native.bashkit_result_stdout(pointer)),
        stderr: Native.read(Native.bashkit_result_stderr(pointer)),
        exit_code: Native.bashkit_result_exit_code(pointer),
        error: nil,
        stdout_truncated: flags.anybits?(Native::STDOUT_TRUNCATED),
        stderr_truncated: flags.anybits?(Native::STDERR_TRUNCATED),
        final_env: final_env.empty? ? nil : JSON.parse(final_env),
      )
    ensure
      Native.bashkit_result_free(pointer)
    end
  end
end
