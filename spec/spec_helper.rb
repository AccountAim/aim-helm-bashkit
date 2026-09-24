# frozen_string_literal: true

require "aim-helm-bashkit"

RSpec.configure do |config|
  config.expect_with(:rspec) { it.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
end
