$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "resque/kubernetes"


def with_term_on_empty(value)
  old_value = ENV["TERM_ON_EMPTY"]
  ENV["TERM_ON_EMPTY"] = value
  yield
ensure
  ENV["TERM_ON_EMPTY"] = old_value
end
