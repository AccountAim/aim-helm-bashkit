# frozen_string_literal: true

require "ffi"

module AimHelmBashkit
  # FFI bindings to libbashkit's C ABI (crates/bashkit-capi/include/bashkit.h).
  #
  # @api private
  module Native
    extend FFI::Library

    LIB_FILE = "libbashkit.#{FFI::Platform::LIBSUFFIX}".freeze
    ABI_VERSION = 1

    OK = 0
    EXECUTION_ERROR = 4
    IO_ERROR = 5
    CANCELLED = 7
    # Statuses meaning the script ran but could not finish, reported as a result.
    FAILED_RUN = [EXECUTION_ERROR, CANCELLED].freeze
    STDOUT_TRUNCATED = 1 << 0
    STDERR_TRUNCATED = 1 << 1

    def self.library_path
      ENV.fetch("AIM_HELM_BASHKIT_LIB_PATH") { File.expand_path(LIB_FILE, __dir__) }
    end

    begin
      ffi_lib library_path
    rescue LoadError => e
      raise LibraryNotFoundError, <<~MSG
        Could not load #{LIB_FILE}: #{e.message}
        Run `rake native:fetch`, or set AIM_HELM_BASHKIT_LIB_PATH to the library.
      MSG
    end

    class Bytes < FFI::Struct
      layout :ptr, :pointer, :len, :size_t

      def self.from(string) = new.tap { it.string = string.to_s }

      # The struct holds the buffer so it lives as long as the struct.
      def string=(string)
        @memory = FFI::MemoryPointer.new(:uint8, string.bytesize)
        @memory.put_bytes(0, string)
        self[:ptr] = @memory
        self[:len] = string.bytesize
      end
    end

    attach_function :bashkit_abi_version, [], :uint32
    attach_function :bashkit_version, [], Bytes.by_value
    attach_function :bashkit_capabilities_json, [], Bytes.by_value

    attach_function :bashkit_create_json, [Bytes.by_value, :pointer, :pointer], :uint32
    attach_function :bashkit_free, [:pointer], :void
    attach_function :bashkit_execute, [:pointer, Bytes.by_value, :pointer, :pointer], :uint32,
                    blocking: true
    attach_function :bashkit_cancel, [:pointer], :uint32
    attach_function :bashkit_clear_cancel, [:pointer], :uint32

    attach_function :bashkit_result_exit_code, [:pointer], :int32
    attach_function :bashkit_result_stdout, [:pointer], Bytes.by_value
    attach_function :bashkit_result_stderr, [:pointer], Bytes.by_value
    attach_function :bashkit_result_flags, [:pointer], :uint32
    attach_function :bashkit_result_final_env_json, [:pointer], Bytes.by_value
    attach_function :bashkit_result_free, [:pointer], :void

    attach_function :bashkit_write_file, [:pointer, Bytes.by_value, Bytes.by_value, :pointer],
                    :uint32, blocking: true
    attach_function :bashkit_read_file, [:pointer, Bytes.by_value, :pointer, :pointer], :uint32,
                    blocking: true
    attach_function :bashkit_mkdir, [:pointer, Bytes.by_value, :uint32, :pointer], :uint32
    attach_function :bashkit_remove, [:pointer, Bytes.by_value, :uint32, :pointer], :uint32

    attach_function :bashkit_buffer_bytes, [:pointer], Bytes.by_value
    attach_function :bashkit_buffer_free, [:pointer], :void

    attach_function :bashkit_error_code, [:pointer], :uint32
    attach_function :bashkit_error_message, [:pointer], Bytes.by_value
    attach_function :bashkit_error_free, [:pointer], :void

    unless (abi = bashkit_abi_version) == ABI_VERSION
      raise Error, "#{library_path} speaks bashkit ABI #{abi}, expected #{ABI_VERSION}"
    end

    class << self
      # Calls a status-returning function whose trailing argument is `BashkitError **`.
      # Yields the status and message for a non-OK status; raises when there is no block.
      def call(function, *)
        error_out = FFI::MemoryPointer.new(:pointer)
        status = public_send(function, *, error_out)
        return status if status == OK

        message = take_error(error_out.read_pointer)
        return yield(status, message) if block_given?

        raise Error.new(message, code: status)
      end

      def bytes(string) = Bytes.from(string)

      def read(bytes)
        return +"" if bytes[:len].zero?

        bytes[:ptr].read_bytes(bytes[:len]).force_encoding(Encoding::UTF_8)
      end

      def take_buffer(pointer)
        read(bashkit_buffer_bytes(pointer))
      ensure
        bashkit_buffer_free(pointer)
      end

      private

      def take_error(pointer)
        return "bashkit call failed" if pointer.null?

        read(bashkit_error_message(pointer))
      ensure
        bashkit_error_free(pointer) unless pointer.null?
      end
    end
  end
end
