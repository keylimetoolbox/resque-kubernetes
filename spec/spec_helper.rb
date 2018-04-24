# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "resque/kubernetes"

RSpec.configure do |config|
  config.order = "random"
  config.filter_run_when_matching focus: true
  config.filter_run_excluding type: "e2e"
end

def with_term_on_empty(value)
  old_value = ENV["TERM_ON_EMPTY"]
  ENV["TERM_ON_EMPTY"] = value
  yield
ensure
  ENV["TERM_ON_EMPTY"] = old_value
end
