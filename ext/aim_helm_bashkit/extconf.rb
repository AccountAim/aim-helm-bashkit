# frozen_string_literal: true

# Source installs download the official libbashkit for this platform. Platform
# gems bundle the library and drop this extension.

require_relative "../../scripts/native_release"

lib_dir = File.expand_path("../../lib/aim_helm_bashkit", __dir__)

if Dir[File.join(lib_dir, "libbashkit.{so,dylib}")].any?
  puts "libbashkit already present in #{lib_dir}, skipping."
else
  platform = NativeRelease.host_platform or abort <<~MSG
    ERROR: no prebuilt libbashkit for #{RbConfig::CONFIG["host_os"]} / #{RbConfig::CONFIG["host_cpu"]}.
    Build it from #{NativeRelease::REPO} with ./scripts/build-c-api.sh --release
    and set AIM_HELM_BASHKIT_LIB_PATH.
  MSG
  NativeRelease.install(platform, lib_dir)
end

# Required by the rubygems extension protocol.
File.write(File.join(__dir__, "Makefile"), "all:\ninstall:\nclean:\n")
