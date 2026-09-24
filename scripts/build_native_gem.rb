# frozen_string_literal: true

# Packages lib/aim_helm_bashkit/libbashkit.{so,dylib} (see fetch_native.rb) into a
# platform gem under pkg/.
#
#   ruby scripts/build_native_gem.rb arm64-darwin

require "rubygems/package"
require "fileutils"

platform = ARGV[0] or abort "Usage: #{$PROGRAM_NAME} PLATFORM"

lib_dir = File.expand_path("../lib/aim_helm_bashkit", __dir__)
native_libs = Dir[File.join(lib_dir, "libbashkit.{so,dylib}")]
abort "ERROR: no libbashkit.so or .dylib in #{lib_dir}" if native_libs.empty?

spec = Gem::Specification.load(File.expand_path("../aim-helm-bashkit.gemspec", __dir__))
spec.platform = Gem::Platform.new(platform)
# The library is bundled, so extconf.rb must not run on install.
spec.extensions = []
spec.files |= native_libs.map { "lib/aim_helm_bashkit/#{File.basename(it)}" }

FileUtils.mkdir_p("pkg")
gem_file = Gem::Package.build(spec)
FileUtils.mv(gem_file, "pkg/")

puts "Built pkg/#{File.basename(gem_file)}"
