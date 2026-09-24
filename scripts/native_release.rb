# frozen_string_literal: true

require "digest"
require "fileutils"
require "open-uri"
require "rbconfig"
require "tmpdir"
require_relative "../lib/aim_helm_bashkit/version"

# Upstream bashkit-capi release archives, keyed by gem platform.
module NativeRelease
  REPO = "https://github.com/everruns/bashkit"

  TARGETS = {
    "x86_64-linux-gnu" => "x86_64-unknown-linux-gnu",
    "aarch64-linux-gnu" => "aarch64-unknown-linux-gnu",
    "x86_64-darwin" => "x86_64-apple-darwin",
    "arm64-darwin" => "aarch64-apple-darwin",
  }.freeze

  module_function

  def host_platform
    cpu = RbConfig::CONFIG["host_cpu"]
    case RbConfig::CONFIG["host_os"]
    when /linux/ then "#{cpu == "arm64" ? "aarch64" : cpu}-linux-gnu"
    when /darwin/ then "#{cpu == "x86_64" ? "x86_64" : "arm64"}-darwin"
    end
  end

  def install(platform, lib_dir)
    target = TARGETS.fetch(platform) do
      abort "ERROR: no prebuilt libbashkit for #{platform.inspect}. " \
            "Known: #{TARGETS.keys.join(", ")}"
    end

    archive = "bashkit-capi-#{target}.tar.gz"
    base = "#{REPO}/releases/download/v#{AimHelmBashkit::BASHKIT_VERSION}"
    puts "Downloading #{base}/#{archive}..."
    tarball = URI.parse("#{base}/#{archive}").open.read
    expected = URI.parse("#{base}/#{archive}.sha256").open.read[/\A\h{64}/]
    unless Digest::SHA256.hexdigest(tarball) == expected
      abort "ERROR: checksum mismatch for #{archive}"
    end

    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, archive), tarball)
      system("tar", "xzf", archive, chdir: dir) or abort "ERROR: tar extraction failed"

      library = Dir[File.join(dir, "*", "lib", "libbashkit.{so,dylib}")].first
      abort "ERROR: libbashkit not found in #{archive}" unless library

      FileUtils.mkdir_p(lib_dir)
      FileUtils.cp(library, lib_dir, verbose: true)
    end
  end
end
