# frozen_string_literal: true

require_relative "lib/aim_helm_bashkit/version"

Gem::Specification.new do |spec|
  spec.name = "aim-helm-bashkit"
  spec.version = AimHelmBashkit::VERSION
  spec.authors = ["Accountaim"]
  spec.summary = "Ruby bindings for Bashkit, a sandboxed bash interpreter"
  spec.description = <<~DESC
    Wraps the Bashkit C ABI: run bash scripts in-process against a virtual
    filesystem, with limits and cancellation, and sync named files with a
    host-supplied document store.
  DESC
  spec.homepage = "https://github.com/AccountAim/aim-helm-bashkit"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.files = Dir.chdir(__dir__) do
    Dir["{lib,ext}/**/*", "scripts/native_release.rb", "Gemfile", "Rakefile",
        "aim-helm-bashkit.gemspec", "README.md", "LICENSE"]
      .grep_v(%r{\Alib/aim_helm_bashkit/libbashkit\.(so|dylib)\z})
  end

  spec.require_paths = ["lib"]
  spec.extensions = ["ext/aim_helm_bashkit/extconf.rb"]

  spec.add_dependency "ffi", "~> 1.15"

  spec.metadata = {
    "source_code_uri" => "https://github.com/AccountAim/aim-helm-bashkit",
    "rubygems_mfa_required" => "true",
  }
end
