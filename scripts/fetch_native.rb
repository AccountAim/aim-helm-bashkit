# frozen_string_literal: true

# Downloads the checksum-verified libbashkit release archive into lib/aim_helm_bashkit/.
#
#   ruby scripts/fetch_native.rb [PLATFORM]
#
# PLATFORM defaults to the host; see TARGETS for known platforms.

require_relative "native_release"

platform = ARGV[0] || NativeRelease.host_platform
NativeRelease.install(platform, File.expand_path("../lib/aim_helm_bashkit", __dir__))
