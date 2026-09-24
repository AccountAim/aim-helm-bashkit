# frozen_string_literal: true

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

namespace :native do
  desc "Fetch the prebuilt libbashkit for this platform"
  task :fetch do
    ruby "scripts/fetch_native.rb"
  end
end

task default: :spec
