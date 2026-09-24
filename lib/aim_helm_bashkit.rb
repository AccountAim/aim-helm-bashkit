# frozen_string_literal: true

require_relative "aim_helm_bashkit/version"
require_relative "aim_helm_bashkit/error"
require_relative "aim_helm_bashkit/native"
require_relative "aim_helm_bashkit/exec_result"
require_relative "aim_helm_bashkit/bash"
require_relative "aim_helm_bashkit/workspace"

# Ruby bindings for Bashkit, a sandboxed bash interpreter with a virtual filesystem.
module AimHelmBashkit
  class << self
    def version = Native.read(Native.bashkit_version)
    def capabilities = JSON.parse(Native.read(Native.bashkit_capabilities_json))
  end
end
