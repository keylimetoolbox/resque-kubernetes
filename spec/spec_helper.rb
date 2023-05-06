# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "resque/kubernetes"

RSpec.configure do |config|
  config.order = "random"
  config.filter_run_when_matching focus: true
  config.filter_run_excluding type: "e2e"

  config.before do
    allow(Resque::Kubernetes).to receive(:enabled).and_return(true)
  end
end

# In tests, don't do exponential back-off, and don't pause between tries
Retriable.configure do |c|
  c.multiplier    = 1.0
  c.rand_factor   = 0.0
  c.base_interval = 0
  c.tries         = 2

  c.contexts.each_key do |context|
    c.contexts[context][:tries]         = 2
    c.contexts[context][:base_interval] = 0
  end
end
