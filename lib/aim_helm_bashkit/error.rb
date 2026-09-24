# frozen_string_literal: true

module AimHelmBashkit
  # `code` is the bashkit ABI status when the failure came from the native call.
  class Error < StandardError
    attr_reader :code

    def initialize(message = nil, code: nil)
      @code = code
      super(message)
    end
  end

  class LibraryNotFoundError < Error; end

  # Raised by `execute!` when the script exits nonzero or fails to run.
  class BashError < Error
    attr_reader :result

    def initialize(result)
      @result = result
      super(result.error || "exit #{result.exit_code}: #{result.stderr}")
    end

    def exit_code = result.exit_code
    def stderr = result.stderr
  end
end
