# frozen_string_literal: true

module AimHelmBashkit
  # `error` is set when the script could not run to completion: parse errors,
  # exceeded limits, timeouts, and cancellation.
  ExecResult = Data.define(
    :stdout, :stderr, :exit_code, :error, :stdout_truncated, :stderr_truncated, :final_env
  ) do
    def self.failure(message)
      new(
        stdout: +"", stderr: message, exit_code: 1, error: message,
        stdout_truncated: false, stderr_truncated: false, final_env: nil
      )
    end

    def success? = exit_code.zero?
  end
end
